#!/usr/bin/env bash
#
# sync-upstream.sh — Import TPC-DS derived SQL from pinned upstream sources.
#                    핀 고정된 상류 소스에서 TPC-DS 파생 SQL을 가져옵니다.
#
# Every file this script writes carries a provenance header naming the upstream
# repository, commit, path, and license, plus any adaptation applied.
# 이 스크립트가 쓰는 모든 파일에는 상류 리포지토리/커밋/경로/라이선스와
# 적용된 변환 내용을 명시한 출처 헤더가 들어갑니다.
#
# Nothing under a TPC-only licence (e.g. the dsdgen/dsqgen toolkit, the official
# query templates, the answer sets) is fetched or vendored here. See NOTICE.md.
# TPC 전용 라이선스 자산(dsdgen/dsqgen 툴킷, 공식 쿼리 템플릿, 정답 세트)은
# 가져오지도 vendoring 하지도 않습니다. NOTICE.md 참고.
#
# Usage / 사용법:
#   tools/sync-upstream.sh [clickhouse|starrocks|postgres|vertica|duckdb|all]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${TPCDS_STAGE:-$REPO_ROOT/.upstream-cache}"

# ---------------------------------------------------------------------------
# Pinned upstream revisions / 핀 고정된 상류 리비전
# Bump these deliberately, then re-run and review the diff.
# 의도적으로 올린 뒤 재실행하고 diff를 검토하세요.
# ---------------------------------------------------------------------------
CH_REPO="ClickHouse/ClickHouse"
CH_REF="4efb1206aa13411eb1bab37a1f1902af486b1e60"
CH_PATH="tests/benchmarks/tpc-ds"
CH_LICENSE="Apache-2.0"

SR_REPO="StarRocks/starrocks"
SR_REF="9d288306166d2f8ab2ba0294511f977a7da36a1e"
SR_PATH="fe/fe-core/src/test/resources/sql/tpcds"
SR_LICENSE="Apache-2.0"

TABLES=(
  call_center catalog_page catalog_returns catalog_sales customer
  customer_address customer_demographics date_dim household_demographics
  income_band inventory item promotion reason ship_mode store store_returns
  store_sales time_dim warehouse web_page web_returns web_sales web_site
)

# Queries 14 / 23 / 24 / 39 each have two formulations, giving 103 streams.
# 쿼리 14/23/24/39는 각각 두 가지 정식화가 있어 총 103개 스트림입니다.
VARIANT_QUERIES=(14 23 24 39)

# Scratch space for intermediate files, cleaned up once when the script exits.
#
# This used to be a per-function `mktemp -d` with `trap ... RETURN`, which is subtly
# wrong: a RETURN trap set inside a function is NOT scoped to that function, so it keeps
# firing on every later function return. By the time the last one ran, the local it
# referenced was out of scope and `set -u` aborted the script — after all the files had
# been written, so it looked like a mysterious failure at the very end. bash 3.2 on macOS
# tolerates it and bash 5 on Linux does not, which is why only CI caught it.
# 중간 파일용 스크래치 공간이며 스크립트 종료 시 한 번 정리합니다.
#
# 이전에는 함수마다 `mktemp -d` 와 `trap ... RETURN` 을 사용했는데 이는 미묘하게
# 잘못되었습니다. 함수 안에서 설정한 RETURN 트랩은 해당 함수에 국한되지 않으므로 이후 모든
# 함수 반환에서 계속 실행됩니다. 마지막 실행 시점에는 트랩이 참조하는 지역 변수가 범위를
# 벗어나 `set -u` 가 스크립트를 중단시켰습니다. 모든 파일이 이미 기록된 뒤였기 때문에 맨
# 끝에서 알 수 없는 실패가 나는 것처럼 보였습니다. macOS 의 bash 3.2 는 이를 허용하고
# Linux 의 bash 5 는 허용하지 않아, CI 에서만 드러났습니다.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

log()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

raw_url() { printf 'https://raw.githubusercontent.com/%s/%s/%s' "$1" "$2" "$3"; }

# fetch <repo> <ref> <path-in-repo> <dest>
fetch() {
  local url; url="$(raw_url "$1" "$2" "$3")"
  curl -fsS --retry 3 --retry-delay 1 --max-time 60 -o "$4" "$url" \
    || die "fetch failed: $url"
}

# is_variant <query-number>
is_variant() {
  local n; n=$((10#$1))
  for v in "${VARIANT_QUERIES[@]}"; do [[ $n -eq $v ]] && return 0; done
  return 1
}

# split_statements <src> <out-prefix>
# Splits a file holding two SQL statements into <prefix>_1.sql / <prefix>_2.sql.
# 두 개의 SQL 문이 담긴 파일을 <prefix>_1.sql / <prefix>_2.sql 로 분리합니다.
split_statements() {
  local src="$1" prefix="$2"
  awk -v p="$prefix" '
    { buf = buf $0 "\n" }
    /;[[:space:]]*$/ { n++; printf "%s", buf > (p "_" n ".sql"); close(p "_" n ".sql"); buf = "" }
    END {
      if (buf ~ /[^[:space:]]/) { n++; printf "%s", buf > (p "_" n ".sql") }
      if (n != 2) { print "expected 2 statements in " FILENAME ", got " n > "/dev/stderr"; exit 1 }
    }
  ' "$src"
}

# header <engine> <query-label> <upstream-repo> <ref> <path> <license> <adaptation>
header() {
  cat <<EOF
-- TPC-DS query $2 — $1
--
-- Upstream / 상류 출처: $3 @ ${4:0:12}
--   $5
--   License / 라이선스: $6
-- Adaptation / 변환: $7
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
EOF
}

# ---------------------------------------------------------------------------
# Stage upstream trees / 상류 트리 스테이징
# ---------------------------------------------------------------------------
stage_clickhouse() {
  local d="$STAGE/clickhouse"; mkdir -p "$d/queries"
  [[ -f "$d/.done" ]] && { log "ClickHouse already staged (rm $d to refetch)"; return; }
  log "Staging $CH_REPO @ ${CH_REF:0:12} — $CH_PATH"
  local pids=()
  for i in $(seq -w 1 99); do
    fetch "$CH_REPO" "$CH_REF" "$CH_PATH/queries/query_$i.sql" "$d/queries/query_$i.sql" & pids+=($!)
    (( ${#pids[@]} % 16 == 0 )) && { wait "${pids[@]}"; pids=(); }
  done
  [[ ${#pids[@]} -gt 0 ]] && wait "${pids[@]}"
  for f in init.sql settings.json README.md; do
    fetch "$CH_REPO" "$CH_REF" "$CH_PATH/$f" "$d/$f"
  done
  touch "$d/.done"
}

stage_starrocks() {
  local d="$STAGE/starrocks"; mkdir -p "$d"
  [[ -f "$d/.done" ]] && { log "StarRocks already staged (rm $d to refetch)"; return; }
  log "Staging $SR_REPO @ ${SR_REF:0:12} — $SR_PATH"
  local pids=()
  for t in "${TABLES[@]}"; do
    fetch "$SR_REPO" "$SR_REF" "$SR_PATH/$t.sql" "$d/$t.sql" & pids+=($!)
  done
  wait "${pids[@]}"; pids=()
  for i in $(seq -w 1 99); do
    if is_variant "$i"; then
      for v in 1 2; do
        fetch "$SR_REPO" "$SR_REF" "$SR_PATH/query$i-$v.sql" "$d/query$i-$v.sql" & pids+=($!)
      done
    else
      fetch "$SR_REPO" "$SR_REF" "$SR_PATH/query$i.sql" "$d/query$i.sql" & pids+=($!)
    fi
    (( ${#pids[@]} >= 16 )) && { wait "${pids[@]}"; pids=(); }
  done
  [[ ${#pids[@]} -gt 0 ]] && wait "${pids[@]}"
  touch "$d/.done"
}

# ---------------------------------------------------------------------------
# Per-engine import / 엔진별 임포트
# ---------------------------------------------------------------------------

# ClickHouse: taken as-is. Upstream already targets ClickHouse SQL.
# ClickHouse: 그대로 사용. 상류가 이미 ClickHouse SQL 방언입니다.
import_clickhouse() {
  stage_clickhouse
  local src="$STAGE/clickhouse" out="$REPO_ROOT/engines/clickhouse"
  mkdir -p "$out/queries" "$out/ddl" "$out/reference"
  log "Importing ClickHouse query set → engines/clickhouse/queries"
  local tmp="$SCRATCH/clickhouse-split"
  mkdir -p "$tmp"
  for i in $(seq -w 1 99); do
    local up="$CH_PATH/queries/query_$i.sql"
    if is_variant "$i"; then
      ( cd "$tmp" && split_statements "$src/queries/query_$i.sql" "q" )
      for v in 1 2; do
        { header "ClickHouse" "$i (formulation $v)" "$CH_REPO" "$CH_REF" "$up" "$CH_LICENSE" \
            "none — imported verbatim; the upstream file holds both formulations and was split"
          cat "$tmp/q_$v.sql"; } > "$out/queries/query${i}_${v}.sql"
      done
      rm -f "$tmp"/q_*.sql
    else
      { header "ClickHouse" "$i" "$CH_REPO" "$CH_REF" "$up" "$CH_LICENSE" "none — imported verbatim"
        cat "$src/queries/query_$i.sql"; } > "$out/queries/query$i.sql"
    fi
  done
  { header "ClickHouse" "schema" "$CH_REPO" "$CH_REF" "$CH_PATH/init.sql" "$CH_LICENSE" "none — imported verbatim"
    cat "$src/init.sql"; } > "$out/ddl/schema.sql"
  cp "$src/settings.json" "$out/reference/upstream-settings.json"
  cp "$src/README.md" "$out/reference/upstream-known-issues.md"
  log "ClickHouse: $(ls "$out/queries" | wc -l | tr -d ' ') queries, schema, known-issues note"
}

# StarRocks: taken as-is. Upstream DDL carries StarRocks distribution clauses.
# StarRocks: 그대로 사용. 상류 DDL에 StarRocks 분산 절이 포함되어 있습니다.
import_starrocks() {
  stage_starrocks
  local src="$STAGE/starrocks" out="$REPO_ROOT/engines/starrocks"
  mkdir -p "$out/queries" "$out/ddl"
  log "Importing StarRocks query set → engines/starrocks/queries"
  for i in $(seq -w 1 99); do
    if is_variant "$i"; then
      for v in 1 2; do
        { header "StarRocks" "$i (formulation $v)" "$SR_REPO" "$SR_REF" "$SR_PATH/query$i-$v.sql" \
            "$SR_LICENSE" "none — imported verbatim"
          cat "$src/query$i-$v.sql"; } > "$out/queries/query${i}_${v}.sql"
      done
    else
      { header "StarRocks" "$i" "$SR_REPO" "$SR_REF" "$SR_PATH/query$i.sql" "$SR_LICENSE" \
          "none — imported verbatim"
        cat "$src/query$i.sql"; } > "$out/queries/query$i.sql"
    fi
  done
  { header "StarRocks" "schema" "$SR_REPO" "$SR_REF" "$SR_PATH/<table>.sql" "$SR_LICENSE" \
      "concatenated per-table files into one schema script; removed the call_center RANGE partition (see below)"
    for t in "${TABLES[@]}"; do printf '\n'; drop_unloadable_partition < "$src/$t.sql"; printf '\n'; done
  } > "$out/ddl/schema.sql"
  log "StarRocks: $(ls "$out/queries" | wc -l | tr -d ' ') queries, schema"
}

# The upstream call_center DDL carries
#   partition by range(cc_rec_start_date) (START ("2023-06-01") END ("2023-07-01") ...)
# which no TPC-DS row can satisfy: dsdgen writes cc_rec_start_date in 1998-2002, so every
# row falls outside the range and the load rejects all of them. Upstream uses these files
# as planner-test fixtures, never as a load target, so the clause is harmless there and
# fatal here. Removing it leaves an unpartitioned table, which is what the other 23
# tables already are.
# 상류 call_center DDL 에는
#   partition by range(cc_rec_start_date) (START ("2023-06-01") END ("2023-07-01") ...)
# 가 있는데 어떤 TPC-DS 행도 이를 만족할 수 없습니다. dsdgen 은 cc_rec_start_date 를
# 1998~2002 년으로 기록하므로 모든 행이 범위를 벗어나 적재가 전부 거부됩니다. 상류는 이
# 파일들을 적재 대상이 아니라 플래너 테스트 픽스처로 쓰기 때문에 그쪽에서는 무해하지만
# 여기서는 치명적입니다. 절을 제거하면 나머지 23개 테이블과 동일하게 파티션 없는 테이블이
# 됩니다.
drop_unloadable_partition() {
  awk '
    /^[[:space:]]*partition by range/ { skip = 1; next }
    skip && /^[[:space:]]*\)[[:space:]]*$/ { skip = 0; next }
    skip { next }
    { print }
  '
}

# Postgres / Vertica / DuckDB: derived from the StarRocks copy of the standard query text,
# which is the plain TPC-DS qualification wording. The only dialect fix needed is
# MySQL-style date_add() -> standard DATE + INTEGER arithmetic.
# DuckDB takes the PostgreSQL text as is (it parses PostgreSQL SQL) and carries a
# DuckDB-only fix solely for the queries that fail on it — see duckdb_fix() below.
# Postgres / Vertica / DuckDB: StarRocks에 담긴 표준 TPC-DS qualification 원문에서 파생합니다.
# 필요한 방언 수정은 MySQL 스타일 date_add() -> 표준 DATE + INTEGER 연산뿐입니다.
# DuckDB 는 PostgreSQL 원문을 그대로 사용하며(PostgreSQL SQL 을 파싱합니다), 실패하는
# 쿼리에만 DuckDB 전용 수정을 적용합니다. 아래 duckdb_fix() 참고.
derive_ansi() {
  local engine="$1" label="$2"
  stage_starrocks
  local src="$STAGE/starrocks" out="$REPO_ROOT/engines/$engine"
  mkdir -p "$out/queries" "$out/ddl"
  log "Deriving $label query set → engines/$engine/queries"

  local adapt="date_add(cast('d' as date), n) -> (cast('d' as date) \+/- n); ORDER BY alias 'lochierarchy' expanded to its defining expression (q36/q70/q86)"
  local total=0
  for i in $(seq -w 1 99); do
    if is_variant "$i"; then
      for v in 1 2; do
        { header "$label" "$i (formulation $v)" "$SR_REPO" "$SR_REF" "$SR_PATH/query$i-$v.sql" \
            "$SR_LICENSE" "$(adaptation_for "$engine" "$i" "$adapt")"
          query_text "$engine" "$i" < "$src/query$i-$v.sql"; } > "$out/queries/query${i}_${v}.sql"
        total=$((total + 1))
      done
    else
      { header "$label" "$i" "$SR_REPO" "$SR_REF" "$SR_PATH/query$i.sql" "$SR_LICENSE" \
          "$(adaptation_for "$engine" "$i" "$adapt")"
        query_text "$engine" "$i" < "$src/query$i.sql"; } > "$out/queries/query$i.sql"
      total=$((total + 1))
    fi
  done
  log "$label: $total queries"

  # Fail loudly rather than shipping a query the engine cannot parse. Comment
  # lines are skipped because the provenance header names the rewritten function.
  # 엔진이 파싱할 수 없는 쿼리를 조용히 내보내지 않고 즉시 실패합니다. 출처 헤더가
  # 변환된 함수명을 언급하므로 주석 줄은 검사에서 제외합니다.
  local leftover=()
  for f in "$out"/queries/*.sql; do
    grep -v '^[[:space:]]*--' "$f" | grep -qi 'date_add' && leftover+=("$f")
  done
  [[ ${#leftover[@]} -gt 0 ]] && die "date_add survived the rewrite in: ${leftover[*]}"
  return 0
}

# The two functions below decide, per engine, which text a query file carries and which
# adaptation its header states. Postgres and Vertica carry to_ansi() output. DuckDB carries
# the same text, passed through duckdb_fix().
# 아래 두 함수는 엔진별로 쿼리 파일에 들어갈 본문과 헤더에 적을 변환 설명을 정합니다.
# Postgres 와 Vertica 는 to_ansi() 출력을, DuckDB 는 같은 본문에 duckdb_fix() 를 거친
# 결과를 담습니다.
adaptation_for() {
  local engine="$1" num="$2" base="$3"
  if [[ "$engine" == duckdb ]]; then
    duckdb_note "$((10#$num))"
  else
    printf '%s' "$base"
  fi
}

# query_text <engine> <query-number> — stdin: upstream text, stdout: the file body.
# For DuckDB a fix must change the text and no-fix must leave it byte-identical to the
# PostgreSQL text, so a stale or mistyped pattern fails here instead of shipping silently.
# query_text <engine> <query-number> — stdin: 상류 원문, stdout: 파일 본문. DuckDB 의 경우
# 수정이 있는 쿼리는 본문이 바뀌어야 하고, 수정이 없는 쿼리는 PostgreSQL 본문과 바이트
# 단위로 같아야 합니다. 낡거나 잘못된 패턴이 조용히 배포되지 않고 여기서 실패합니다.
query_text() {
  local engine="$1" num=$((10#$2))
  if [[ "$engine" != duckdb ]]; then to_ansi; return; fi
  local pg="$SCRATCH/pg-q$num.sql" dk="$SCRATCH/duckdb-q$num.sql"
  to_ansi > "$pg"
  duckdb_fix "$num" < "$pg" > "$dk"
  if [[ -n "$(duckdb_note_raw "$num")" ]]; then
    ! cmp -s "$pg" "$dk" || die "DuckDB fix for q$num did not change the text (pattern is stale)"
  else
    cmp -s "$pg" "$dk" || die "q$num differs from the PostgreSQL text but has no duckdb_note"
  fi
  cat "$dk"
}

# DuckDB-only fixes. Every other query runs on DuckDB unchanged from engines/postgres;
# these two fail to parse there (measured on DuckDB 1.5.6, see docs/engines/duckdb.md):
#   q77  "coalesce(returns, 0) returns" — RETURNS is a keyword in DuckDB, so it needs AS
#        to be an output alias ("as returns" is already used elsewhere in the same query)
#   q90  ") at," — AT is a keyword in DuckDB and cannot name a derived table, even after AS;
#        quoting it keeps the name ("at" is never referenced)
# Both rewrites are also valid PostgreSQL.
# DuckDB 전용 수정. 나머지 쿼리는 engines/postgres 와 동일하게 DuckDB 에서 실행됩니다.
# 아래 두 쿼리만 파싱에 실패합니다(DuckDB 1.5.6 에서 측정, docs/engines/duckdb.md 참고).
#   q77  "coalesce(returns, 0) returns" — DuckDB 에서 RETURNS 는 키워드라 출력 별칭에 AS 가
#        필요합니다(같은 쿼리의 다른 곳이 이미 "as returns" 를 사용).
#   q90  ") at," — DuckDB 에서 AT 는 키워드이며 AS 뒤에서도 파생 테이블 이름이 될 수 없어
#        따옴표로 감쌉니다(이 이름은 참조되지 않음).
# 두 수정 모두 PostgreSQL 에서도 유효합니다.
duckdb_fix() {
  case "$1" in
    77) sed -E 's/coalesce\(returns, 0\) returns$/coalesce(returns, 0) as returns/' ;;
    90) sed -E 's/\) at,$/) as "at",/' ;;
    *)  cat ;;
  esac
}

duckdb_note_raw() {
  case "$1" in
    77) printf 'coalesce(returns, 0) returns -> coalesce(returns, 0) as returns (RETURNS is a DuckDB keyword; an alias needs AS)' ;;
    90) printf 'derived table alias: ) at, -> ) as "at", (AT is a DuckDB keyword; quoted)' ;;
  esac
}

duckdb_note() {
  local raw; raw="$(duckdb_note_raw "$1")"
  if [[ -n "$raw" ]]; then
    printf 'engines/postgres, except: %s (DuckDB-only; the rest is identical to engines/postgres)' "$raw"
  else
    printf 'identical to engines/postgres'
  fi
}

to_ansi() {
  # Offsets may be negative (q21, q40 use -30), so handle the sign explicitly
  # rather than emitting "+ -30".
  # 오프셋이 음수일 수 있으므로(q21, q40은 -30 사용) "+ -30" 대신 부호를 명시적으로 처리합니다.
  sed -E \
    -e "s/date_add\(cast ?\('([0-9]{4}-[0-9]{1,2}-[0-9]{1,2})' as date\), *-([0-9]+)\)/(cast('\1' as date) - \2)/g" \
    -e "s/date_add\(cast ?\('([0-9]{4}-[0-9]{1,2}-[0-9]{1,2})' as date\), *\+?([0-9]+)\)/(cast('\1' as date) + \2)/g" \
  | expand_ordering_alias
}

# Standard SQL lets ORDER BY name an output column only as a bare name, never
# inside a larger expression. TPC-DS q36/q70/q86 write
# "order by ... case when lochierarchy = 0 then <col> end", which PostgreSQL
# rejects with 'column "lochierarchy" does not exist'. Substituting the alias for
# the expression it was defined as is semantically identical.
# 표준 SQL 에서 ORDER BY 는 출력 컬럼명을 단독으로만 참조할 수 있고 더 큰 식
# 안에서는 참조할 수 없습니다. TPC-DS q36/q70/q86 은 ORDER BY 안에서
# "case when lochierarchy = 0 then <col> end" 형태로 별칭을 쓰는데 PostgreSQL 은
# 이를 거부합니다. 별칭을 정의식으로 치환하는 것은 의미상 완전히 동일합니다.
expand_ordering_alias() {
  awk '
    { line[NR] = $0 }
    # capture the defining expression of "<expr> as lochierarchy"
    # "<expr> as lochierarchy" 의 정의식을 추출
    /[[:space:]]as[[:space:]]+lochierarchy/ && expr == "" {
      s = $0
      sub(/^[[:space:]]*,?[[:space:]]*/, "", s)
      sub(/[[:space:]]+as[[:space:]]+lochierarchy.*$/, "", s)
      expr = s
    }
    END {
      for (i = 1; i <= NR; i++) {
        s = line[i]
        if (expr != "") {
          # plain string splice, not sub(): expr contains ( ) + which are regex metachars
          # sub() 대신 문자열 치환: expr 에 ( ) + 등 정규식 메타문자가 포함됨
          while ((p = index(s, "case when lochierarchy")) > 0) {
            s = substr(s, 1, p - 1) "case when " expr substr(s, p + length("case when lochierarchy"))
          }
        }
        print s
      }
    }
  '
}

# ---------------------------------------------------------------------------
main() {
  command -v curl >/dev/null || die "curl is required"
  mkdir -p "$STAGE"
  case "${1:-all}" in
    clickhouse) import_clickhouse ;;
    starrocks)  import_starrocks ;;
    postgres)   derive_ansi postgres PostgreSQL ;;
    vertica)    derive_ansi vertica Vertica ;;
    duckdb)     derive_ansi duckdb DuckDB ;;
    all)
      import_clickhouse
      import_starrocks
      derive_ansi postgres PostgreSQL
      derive_ansi vertica Vertica
      derive_ansi duckdb DuckDB
      ;;
    *) die "unknown target: $1 (expected clickhouse|starrocks|postgres|vertica|duckdb|all)" ;;
  esac
  log "Done. Oracle assets are repo-native and are not touched by this script."
  log "완료. Oracle 자산은 리포 고유 자산이며 이 스크립트가 건드리지 않습니다."
}

main "$@"
