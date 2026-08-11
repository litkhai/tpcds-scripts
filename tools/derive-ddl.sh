#!/usr/bin/env bash
#
# derive-ddl.sh — Generate PostgreSQL and Vertica schemas from the repo-native
#                 Oracle schema, which is plain TPC-DS column text.
#                 리포 고유 Oracle 스키마(TPC-DS 표준 컬럼 정의)에서
#                 PostgreSQL / Vertica 스키마를 생성합니다.
#
# The Oracle schema in engines/oracle/ddl/schema.sql uses only integer, char(N),
# varchar(N), decimal(P,S) and date — all of which PostgreSQL and Vertica accept
# verbatim. The single fix needed is dv_create_time, which Oracle stores as date
# because it has no TIME type; dsdgen emits HH:MM:SS there.
# engines/oracle/ddl/schema.sql 은 integer, char(N), varchar(N), decimal(P,S),
# date 만 사용하며 PostgreSQL / Vertica 가 그대로 받아들입니다. 유일한 수정은
# dv_create_time 으로, Oracle 은 TIME 타입이 없어 date 로 두었지만 dsdgen 은
# HH:MM:SS 를 출력합니다.
#
# Usage / 사용법: tools/derive-ddl.sh [postgres|vertica|all]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/engines/oracle/ddl/schema.sql"

log() { printf '\033[36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f "$SRC" ]] || die "missing source schema: $SRC"

header() {
  cat <<EOF
--
-- TPC-DS schema — $1
--
-- Derived from / 파생 출처: engines/oracle/ddl/schema.sql (repo-native / 리포 고유)
-- Adaptation / 변환:
--   * dv_create_time: date -> time (Oracle has no TIME type; dsdgen emits HH:MM:SS)
--     dv_create_time: date -> time (Oracle 은 TIME 타입이 없음; dsdgen 은 HH:MM:SS 출력)
--   * $2
--
-- Primary keys are declared for optimiser benefit and documentation. TPC-DS does
-- not require enforced referential integrity for the load or query phases.
-- 기본키는 옵티마이저 활용과 문서화 목적으로 선언합니다. TPC-DS 는 적재/쿼리
-- 단계에서 참조 정합성 강제를 요구하지 않습니다.
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- Results produced with this schema are not comparable to published TPC-DS results.
-- TPC-DS 는 TPC 의 상표이며, 본 스키마로 측정한 결과는 공표된 TPC-DS 결과와
-- 비교할 수 없습니다. See / 참고: NOTICE.md
--
EOF
}

derive_postgres() {
  local out="$REPO_ROOT/engines/postgres/ddl"; mkdir -p "$out"
  { header "PostgreSQL" "no other change — the column text is already valid PostgreSQL / 그 외 변경 없음"
    sed -E 's/^([[:space:]]*dv_create_time[[:space:]]+)date/\1time/' "$SRC"
  } > "$out/schema.sql"
  log "postgres: engines/postgres/ddl/schema.sql ($(grep -ci '^create table' "$out/schema.sql") tables)"
}

derive_vertica() {
  local out="$REPO_ROOT/engines/vertica/ddl"; mkdir -p "$out"
  { header "Vertica" "physical design (projections, segmentation, sort order) lives in engines/vertica/tuning/ / 물리 설계는 engines/vertica/tuning/ 에 있음"
    sed -E 's/^([[:space:]]*dv_create_time[[:space:]]+)date/\1time/' "$SRC"
  } > "$out/schema.sql"
  log "vertica: engines/vertica/ddl/schema.sql ($(grep -ci '^create table' "$out/schema.sql") tables)"
}

case "${1:-all}" in
  postgres) derive_postgres ;;
  vertica)  derive_vertica ;;
  all)      derive_postgres; derive_vertica ;;
  *)        die "unknown target: $1 (expected postgres|vertica|all)" ;;
esac
