#!/usr/bin/env bash
#
# common.sh — Shared helpers for the bin/ scripts.
#             bin/ 스크립트 공용 헬퍼.
#
# Sourced, not executed. / 실행하지 않고 source 합니다.
#
# shellcheck shell=bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

ENGINES=(oracle postgres vertica clickhouse starrocks duckdb)

# TPC-DS table load order: dimensions before facts, so that a run with enforced
# referential integrity also succeeds.
# TPC-DS 적재 순서: 참조 정합성을 강제한 경우에도 성공하도록 차원 → 팩트 순.
TPCDS_TABLES=(
  call_center catalog_page customer_address customer_demographics date_dim
  household_demographics income_band item promotion reason ship_mode store
  time_dim warehouse web_page web_site customer
  inventory store_sales store_returns catalog_sales catalog_returns
  web_sales web_returns
)

# ---------------------------------------------------------------------------
# Output / 출력
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_INFO=$'\033[36m'; C_OK=$'\033[32m'
  C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'
else
  C_RESET=''; C_INFO=''; C_OK=''; C_WARN=''; C_ERR=''; C_DIM=''
fi

log()  { printf '%s==>%s %s\n' "$C_INFO" "$C_RESET" "$*"; }
ok()   { printf '%s[ok]%s %s\n' "$C_OK" "$C_RESET" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
die()  { printf '%s[error]%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2; exit 1; }
dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

# ---------------------------------------------------------------------------
# Engine validation / 엔진 검증
# ---------------------------------------------------------------------------
require_engine() {
  local e="${1:-}"
  [[ -n "$e" ]] || die "no engine given / 엔진이 지정되지 않았습니다 (expected: ${ENGINES[*]})"
  for known in "${ENGINES[@]}"; do
    [[ "$e" == "$known" ]] && return 0
  done
  die "unknown engine '$e' / 알 수 없는 엔진 (expected: ${ENGINES[*]})"
}

engine_dir() { printf '%s/engines/%s' "$REPO_ROOT" "$1"; }

# ---------------------------------------------------------------------------
# Configuration / 설정
#
# Values come from, in increasing precedence:
#   1. config/<engine>.env      (git-ignored, copied from the .example)
#   2. the caller's environment
# 우선순위(뒤가 강함): 1. config/<engine>.env (git 제외), 2. 호출자 환경변수
# ---------------------------------------------------------------------------
load_config() {
  local engine="$1"
  local file="$REPO_ROOT/config/$engine.env"
  if [[ -f "$file" ]]; then
    local before; before="$(export -p)"
    # shellcheck disable=SC1090
    set -a; source "$file"; set +a
    # Re-apply anything the caller set explicitly, so the environment wins.
    # 호출자가 명시한 값을 다시 적용해 환경변수가 우선하도록 합니다.
    eval "$before"
    dim "config: $file"
  else
    warn "no config/$engine.env — using environment defaults / 환경변수 기본값 사용"
    warn "  cp config/$engine.env.example config/$engine.env"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 \
    || die "'$1' not found in PATH / PATH 에 '$1' 이 없습니다${2:+ ($2)}"
}

# ---------------------------------------------------------------------------
# Query selection / 쿼리 선택
#
# Accepts: "all" | "1,5,22" | "14_2" | "1-10"
# 허용 형식: "all" | "1,5,22" | "14_2" | "1-10"
# ---------------------------------------------------------------------------
resolve_queries() {
  local engine="$1" spec="${2:-all}"
  local qdir; qdir="$(engine_dir "$engine")/queries"
  [[ -d "$qdir" ]] || die "no query directory: $qdir"

  if [[ "$spec" == "all" ]]; then
    find "$qdir" -name 'query*.sql' | sort
    return
  fi

  local item out=()
  IFS=',' read -r -a items <<< "$spec"
  for item in "${items[@]}"; do
    if [[ "$item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      local n
      for (( n = BASH_REMATCH[1]; n <= BASH_REMATCH[2]; n++ )); do
        while IFS= read -r f; do out+=("$f"); done \
          < <(find "$qdir" -name "$(printf 'query%02d' "$n").sql" -o -name "$(printf 'query%02d' "$n")_*.sql" | sort)
      done
    elif [[ "$item" =~ ^([0-9]+)_([12])$ ]]; then
      out+=("$qdir/$(printf 'query%02d_%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}").sql")
    elif [[ "$item" =~ ^[0-9]+$ ]]; then
      while IFS= read -r f; do out+=("$f"); done \
        < <(find "$qdir" -name "$(printf 'query%02d' "$item").sql" -o -name "$(printf 'query%02d' "$item")_*.sql" | sort)
    else
      die "cannot parse query spec '$item' / 쿼리 지정을 해석할 수 없습니다"
    fi
  done
  local f
  for f in "${out[@]}"; do
    [[ -f "$f" ]] || die "no such query file: $f"
    printf '%s\n' "$f"
  done
}

query_label() {
  local b; b="$(basename "$1" .sql)"
  printf '%s' "${b#query}"
}

# strip_comments <file> — emit the SQL with our provenance header removed.
# strip_comments <file> — 출처 헤더를 제거한 SQL 을 출력합니다.
strip_comments() { grep -v '^[[:space:]]*--' "$1"; }

# ---------------------------------------------------------------------------
# Data files / 데이터 파일
#
# data_files <dir> <table> — the .dat files belonging to exactly this table.
#
# dsdgen names parallel chunks <table>_<child>_<parallel>.dat. A loose
# "<table>_*.dat" glob would ALSO match other TPC-DS tables that share a prefix:
# customer_address.dat and customer_demographics.dat for "customer",
# store_sales.dat and store_returns.dat for "store". Concatenating those into the
# wrong table produces a load error at best and silent corruption at worst, so the
# chunk suffix is matched strictly as _<digits>_<digits>.
# dsdgen 은 병렬 청크를 <table>_<child>_<parallel>.dat 로 명명합니다. 느슨한
# "<table>_*.dat" 글롭은 접두어를 공유하는 다른 TPC-DS 테이블도 매칭합니다.
# "customer" 에 customer_address.dat·customer_demographics.dat, "store" 에
# store_sales.dat·store_returns.dat 가 걸립니다. 이들을 잘못된 테이블에 이어붙이면
# 최선의 경우 적재 오류, 최악의 경우 조용한 데이터 오염이 발생하므로 청크 접미사를
# _<숫자>_<숫자> 로 엄격히 매칭합니다.
# ---------------------------------------------------------------------------
data_files() {
  local dir="$1" table="$2" f base
  [[ -f "$dir/$table.dat" ]] && printf '%s\n' "$dir/$table.dat"
  local had_nullglob=0
  shopt -q nullglob && had_nullglob=1
  shopt -s nullglob
  for f in "$dir/${table}_"[0-9]*.dat; do
    base="$(basename "$f")"
    [[ "$base" =~ ^"$table"_[0-9]+_[0-9]+\.dat$ ]] && printf '%s\n' "$f"
  done
  [[ $had_nullglob -eq 0 ]] && shopt -u nullglob
  return 0
}

# canonical_columns <table> — the column order the .dat files are written in.
#
# dsdgen writes fields in the TPC-DS specification order, and this repo's Oracle schema
# preserves it, so that schema is the canonical reference. It matters because a loader
# that maps fields positionally breaks against any engine whose CREATE TABLE reorders
# columns: StarRocks puts the duplicate-key columns first in all six fact tables, so a
# positional load would silently write ss_ticket_number into ss_item_sk.
# dsdgen 은 TPC-DS 규격 순서로 필드를 기록하고 이 리포의 Oracle 스키마가 그 순서를
# 유지하므로 해당 스키마가 표준 기준입니다. 이것이 중요한 이유는, 필드를 위치 기반으로
# 매핑하는 로더는 CREATE TABLE 이 컬럼을 재배열하는 엔진에서 깨지기 때문입니다.
# StarRocks 는 6개 팩트 테이블 전부에서 duplicate-key 컬럼을 앞에 두므로, 위치 기반
# 적재는 ss_ticket_number 를 ss_item_sk 에 조용히 기록하게 됩니다.
canonical_columns() {
  awk -v want="$1" '
    BEGIN { inb = 0; n = 0 }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      lower = tolower(line)
      if (!inb) {
        if (lower == "create table " want) { inb = 1 }
        next
      }
      if (line == "(") next
      if (line ~ /^\)/) exit
      if (lower ~ /^primary key/) next
      if (line == "") next
      sub(/,$/, "", line)
      split(line, a, /[[:space:]]+/)
      if (a[1] != "") { printf "%s%s", (n++ ? "," : ""), a[1] }
    }
  ' "$REPO_ROOT/engines/oracle/ddl/schema.sql"
}

# ---------------------------------------------------------------------------
# Per-engine execution / 엔진별 실행
#
# engine_exec <engine> reads SQL on stdin and writes result rows to stdout. It
# must exit non-zero when the engine reports an error, so that a failure is never
# silently recorded as a fast success.
# engine_exec <engine> 는 stdin 으로 SQL 을 받아 결과 행을 stdout 으로 출력합니다.
# 엔진이 오류를 보고하면 반드시 non-zero 로 종료해야 하며, 그래야 실패가
# '빠른 성공' 으로 잘못 기록되지 않습니다.
#
# Connection variables are read from config/<engine>.env — see the .example files.
# 접속 변수는 config/<engine>.env 에서 읽습니다. .example 파일 참고.
# ---------------------------------------------------------------------------
engine_exec() {
  case "$1" in
    oracle)
      # WHENEVER SQLERROR EXIT makes sqlplus return a failing status.
      # WHENEVER SQLERROR EXIT 로 sqlplus 가 실패 상태를 반환하게 합니다.
      { printf 'WHENEVER SQLERROR EXIT SQL.SQLCODE\nWHENEVER OSERROR EXIT 9\n'
        printf 'SET PAGESIZE 0 FEEDBACK OFF HEADING OFF TERMOUT ON TRIMSPOOL ON LINESIZE 32767\n'
        cat
        printf '\nEXIT\n'
      } | sqlplus -S -L "${ORACLE_CONNECT:?set ORACLE_CONNECT in config/oracle.env}"
      ;;
    postgres)
      PGPASSWORD="${PGPASSWORD:-}" psql \
        --host "${PGHOST:-localhost}" --port "${PGPORT:-5432}" \
        --username "${PGUSER:-postgres}" --dbname "${PGDATABASE:-tpcds}" \
        --no-psqlrc --quiet --no-align --tuples-only \
        --set ON_ERROR_STOP=1 --file -
      ;;
    vertica)
      vsql --host "${VHOST:-localhost}" --port "${VPORT:-5433}" \
        --username "${VUSER:-dbadmin}" --dbname "${VDATABASE:-tpcds}" \
        ${VPASSWORD:+--password "$VPASSWORD"} \
        --no-vsqlrc --quiet --no-align --tuples-only \
        --set ON_ERROR_STOP=1 --file -
      ;;
    clickhouse)
      # shellcheck disable=SC2086  # CH_EXTRA_ARGS is intentionally word-split
      clickhouse-client --host "${CH_HOST:-localhost}" --port "${CH_PORT:-9000}" \
        --user "${CH_USER:-default}" --password "${CH_PASSWORD:-}" \
        --database "${CH_DATABASE:-tpcds}" ${CH_EXTRA_ARGS:-} --multiquery
      ;;
    starrocks)
      # StarRocks speaks the MySQL protocol. In batch mode the mysql client already
      # stops at the first error and exits non-zero, so no extra flag is needed —
      # --abort-source-on-error is a MariaDB option and MySQL 8 rejects it outright.
      # StarRocks 는 MySQL 프로토콜을 사용합니다. batch 모드에서 mysql 클라이언트는 이미
      # 첫 오류에서 중단하고 non-zero 로 종료하므로 추가 플래그가 필요 없습니다.
      # --abort-source-on-error 는 MariaDB 옵션이며 MySQL 8 은 이를 거부합니다.
      mysql --host "${SR_HOST:-127.0.0.1}" --port "${SR_PORT:-9030}" \
        --user "${SR_USER:-root}" ${SR_PASSWORD:+--password="$SR_PASSWORD"} \
        --database "${SR_DATABASE:-tpcds}" \
        --batch --raw --skip-column-names
      ;;
    duckdb)
      # -bail stops at the first error, like psql's ON_ERROR_STOP; without it the CLI runs
      # the statements after a failed one (it still exits non-zero at the end — measured on
      # DuckDB 1.5.6). The database is a file, so there is no server:
      # DUCKDB_THREADS / DUCKDB_MEMORY_LIMIT become SET statements.
      # -bail 은 psql 의 ON_ERROR_STOP 처럼 첫 오류에서 중단합니다. 없으면 실패한 문장 뒤의
      # 문장도 실행하며(마지막에는 non-zero 로 종료합니다. DuckDB 1.5.6 에서 측정),
      # 데이터베이스가 파일이므로 서버가 없고 DUCKDB_THREADS / DUCKDB_MEMORY_LIMIT 는 SET
      # 문으로 전달됩니다.
      local db="${DUCKDB_DATABASE:-$REPO_ROOT/.data/tpcds.duckdb}" opts=()
      mkdir -p "$(dirname "$db")"
      [[ -z "${DUCKDB_THREADS:-}" ]] || opts+=(-cmd "SET threads = ${DUCKDB_THREADS}")
      [[ -z "${DUCKDB_MEMORY_LIMIT:-}" ]] || opts+=(-cmd "SET memory_limit = '${DUCKDB_MEMORY_LIMIT}'")
      # -nullvalue '' prints NULL as an empty field, as psql does, so a one-row NULL result
      # counts as no data row in run.sh's row count on both engines.
      # -nullvalue '' 는 psql 처럼 NULL 을 빈 필드로 출력해, NULL 한 행짜리 결과를 두 엔진 모두에서
      # run.sh 의 행 수 계산이 데이터 행으로 세지 않게 합니다.
      # ${opts[@]+...}: an empty array trips set -u on bash 3.2 (macOS).
      # ${opts[@]+...}: 빈 배열은 bash 3.2(macOS)에서 set -u 오류를 일으킵니다.
      duckdb -bail -noheader -list -nullvalue '' ${opts[@]+"${opts[@]}"} "$db"
      ;;
    *) die "engine_exec: unknown engine '$1'" ;;
  esac
}

# engine_exec_nodb <engine> — same, but without selecting a database. Used to
# CREATE DATABASE before the schema exists.
# engine_exec_nodb <engine> — 동일하지만 데이터베이스를 선택하지 않습니다.
# 스키마 생성 전 CREATE DATABASE 용도입니다.
engine_exec_nodb() {
  case "$1" in
    postgres)
      PGPASSWORD="${PGPASSWORD:-}" psql \
        --host "${PGHOST:-localhost}" --port "${PGPORT:-5432}" \
        --username "${PGUSER:-postgres}" --dbname postgres \
        --no-psqlrc --quiet --set ON_ERROR_STOP=1 --file -
      ;;
    clickhouse)
      # shellcheck disable=SC2086
      clickhouse-client --host "${CH_HOST:-localhost}" --port "${CH_PORT:-9000}" \
        --user "${CH_USER:-default}" --password "${CH_PASSWORD:-}" \
        ${CH_EXTRA_ARGS:-} --multiquery
      ;;
    starrocks)
      mysql --host "${SR_HOST:-127.0.0.1}" --port "${SR_PORT:-9030}" \
        --user "${SR_USER:-root}" ${SR_PASSWORD:+--password="$SR_PASSWORD"} \
        --batch --raw --skip-column-names
      ;;
    duckdb)
      # A DuckDB database is a file created on first connect, so there is nothing to
      # CREATE. The SQL is read and discarded to keep the pipe from breaking.
      # DuckDB 데이터베이스는 첫 접속 시 생성되는 파일이라 CREATE 할 것이 없습니다. 파이프가
      # 끊기지 않도록 SQL 은 읽고 버립니다.
      cat >/dev/null
      ;;
    oracle|vertica)
      # Oracle uses a pre-created user/schema; Vertica a pre-created database.
      # Oracle 은 미리 만든 사용자/스키마를, Vertica 는 미리 만든 데이터베이스를 사용합니다.
      die "$1 has no CREATE DATABASE step — create the schema/database first / 스키마·DB를 먼저 생성하세요"
      ;;
    *) die "engine_exec_nodb: unknown engine '$1'" ;;
  esac
}

check_client() {
  case "$1" in
    oracle)     require_cmd sqlplus "Oracle Instant Client" ;;
    postgres)   require_cmd psql "postgresql-client" ;;
    vertica)    require_cmd vsql "Vertica client tools" ;;
    clickhouse) require_cmd clickhouse-client "ClickHouse client" ;;
    starrocks)  require_cmd mysql "mysql client — StarRocks speaks the MySQL protocol" ;;
    duckdb)     require_cmd duckdb "DuckDB CLI — https://duckdb.org/install/" ;;
  esac
}

# ---------------------------------------------------------------------------
# Timing / 타이밍
#
# Wall-clock in milliseconds. `date +%s%3N` is GNU-only, so fall back to python3
# on macOS/BSD.
# 밀리초 단위 실측 시간. `date +%s%3N` 은 GNU 전용이므로 macOS/BSD 에서는
# python3 으로 대체합니다.
# ---------------------------------------------------------------------------
if date +%s%3N 2>/dev/null | grep -qE '^[0-9]+$' && [[ "$(date +%s%3N)" != *N* ]]; then
  now_ms() { date +%s%3N; }
elif command -v python3 >/dev/null 2>&1; then
  now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }
else
  now_ms() { printf '%s000' "$(date +%s)"; }
fi
