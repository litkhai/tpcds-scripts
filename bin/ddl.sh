#!/usr/bin/env bash
#
# ddl.sh — Create the TPC-DS schema (and optionally the tuning objects) on one engine.
#          하나의 엔진에 TPC-DS 스키마(및 선택적으로 튜닝 오브젝트)를 생성합니다.
#
# Usage / 사용법:
#   bin/ddl.sh --engine postgres --create-database
#   bin/ddl.sh --engine clickhouse
#   bin/ddl.sh --engine vertica --tuning
#   bin/ddl.sh --engine postgres --drop
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

ENGINE=""
CREATE_DB=0
WITH_TUNING=0
DROP=0

usage() {
  cat <<'EOF'
Usage / 사용법: bin/ddl.sh --engine <engine> [options]

  --engine <name>     oracle | postgres | vertica | clickhouse | starrocks (required / 필수)
  --create-database   CREATE DATABASE first (postgres, clickhouse, starrocks)
                      데이터베이스를 먼저 생성 (postgres, clickhouse, starrocks)
  --tuning            also apply engines/<engine>/tuning/*.sql
                      engines/<engine>/tuning/*.sql 도 적용
  --drop              DROP the 24 TPC-DS tables, then stop
                      TPC-DS 24개 테이블을 DROP 하고 종료
  -h, --help          show this help / 도움말

Oracle and Vertica expect the schema/database to exist already; see their engine
READMEs. / Oracle 과 Vertica 는 스키마·데이터베이스가 이미 있어야 합니다.
각 엔진 README 참고.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine)          ENGINE="${2:?}"; shift 2 ;;
    --create-database) CREATE_DB=1; shift ;;
    --tuning)          WITH_TUNING=1; shift ;;
    --drop)            DROP=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)                 die "unknown argument '$1' — see --help" ;;
  esac
done

require_engine "$ENGINE"
load_config "$ENGINE"
check_client "$ENGINE"

EDIR="$(engine_dir "$ENGINE")"
SCHEMA="$EDIR/ddl/schema.sql"
[[ -f "$SCHEMA" ]] || die "missing schema: ${SCHEMA#"$REPO_ROOT"/}"

db_name() {
  case "$ENGINE" in
    postgres)   printf '%s' "${PGDATABASE:-tpcds}" ;;
    clickhouse) printf '%s' "${CH_DATABASE:-tpcds}" ;;
    starrocks)  printf '%s' "${SR_DATABASE:-tpcds}" ;;
    vertica)    printf '%s' "${VDATABASE:-tpcds}" ;;
    oracle)     printf '%s' "${ORACLE_SCHEMA:-tpcds}" ;;
  esac
}

if [[ $DROP -eq 1 ]]; then
  log "dropping TPC-DS tables on $ENGINE ($(db_name))"
  # dbgen_version is included because the schema creates it, though no data is loaded.
  # 스키마가 생성하므로 dbgen_version 도 포함합니다(데이터는 적재하지 않음).
  { for t in "${TPCDS_TABLES[@]}" dbgen_version; do
      printf 'DROP TABLE IF EXISTS %s;\n' "$t"
    done
  } | engine_exec "$ENGINE"
  ok "dropped / 삭제 완료"
  exit 0
fi

if [[ $CREATE_DB -eq 1 ]]; then
  log "creating database '$(db_name)' on $ENGINE"
  printf 'CREATE DATABASE IF NOT EXISTS %s;\n' "$(db_name)" \
    | engine_exec_nodb "$ENGINE" 2>/dev/null \
    || {
      # PostgreSQL has no IF NOT EXISTS for CREATE DATABASE, so retry plainly and
      # tolerate "already exists".
      # PostgreSQL 은 CREATE DATABASE 에 IF NOT EXISTS 가 없어 단순 재시도 후
      # "already exists" 는 허용합니다.
      printf 'CREATE DATABASE %s;\n' "$(db_name)" | engine_exec_nodb "$ENGINE" \
        || warn "CREATE DATABASE did not succeed — it may already exist / 이미 존재할 수 있습니다"
    }
fi

log "applying schema: ${SCHEMA#"$REPO_ROOT"/}"
engine_exec "$ENGINE" < "$SCHEMA"
ok "schema applied — $(grep -ciE '^[[:space:]]*create table' "$SCHEMA") tables / 테이블"

if [[ $WITH_TUNING -eq 1 ]]; then
  shopt -s nullglob
  tuning_files=("$EDIR"/tuning/*.sql)
  shopt -u nullglob
  if [[ ${#tuning_files[@]} -eq 0 ]]; then
    warn "no tuning scripts for $ENGINE / 튜닝 스크립트 없음"
  else
    for tf in "${tuning_files[@]}"; do
      log "applying tuning: ${tf#"$REPO_ROOT"/}"
      engine_exec "$ENGINE" < "$tf"
    done
    ok "tuning applied (${#tuning_files[@]} script(s)) / 튜닝 적용 완료"
  fi
fi
