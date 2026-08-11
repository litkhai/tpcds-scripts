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

ENGINES=(oracle postgres vertica clickhouse starrocks)

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
      # StarRocks speaks the MySQL protocol.
      # StarRocks 는 MySQL 프로토콜을 사용합니다.
      mysql --host "${SR_HOST:-127.0.0.1}" --port "${SR_PORT:-9030}" \
        --user "${SR_USER:-root}" ${SR_PASSWORD:+--password="$SR_PASSWORD"} \
        --database "${SR_DATABASE:-tpcds}" \
        --batch --raw --skip-column-names --abort-source-on-error
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
        --batch --raw --skip-column-names --abort-source-on-error
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
