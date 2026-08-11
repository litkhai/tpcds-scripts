#!/usr/bin/env bash
#
# PostgreSQL loader — COPY from the dsdgen .dat files.
# PostgreSQL 로더 — dsdgen .dat 파일을 COPY 로 적재합니다.
#
# dsdgen writes pipe-delimited rows with a trailing delimiter on every line, which
# COPY reads as an extra empty column. The trailing pipe is stripped on the way in
# rather than rewriting the generated files.
# dsdgen 은 파이프 구분 행을 출력하며 각 줄 끝에도 구분자가 붙습니다. COPY 는
# 이를 빈 컬럼으로 인식하므로, 생성 파일을 수정하지 않고 적재 중에 마지막
# 파이프를 제거합니다.
#
# Invoked by bin/load.sh, which exports DATA_DIR, LOG_DIR and TPCDS_LOAD_TABLES.
# bin/load.sh 가 DATA_DIR, LOG_DIR, TPCDS_LOAD_TABLES 를 export 한 뒤 호출합니다.
#
set -euo pipefail
source "$REPO_ROOT/bin/lib/common.sh"

require_cmd psql "postgresql-client"

psql_run() {
  PGPASSWORD="${PGPASSWORD:-}" psql \
    --host "${PGHOST:-localhost}" --port "${PGPORT:-5432}" \
    --username "${PGUSER:-postgres}" --dbname "${PGDATABASE:-tpcds}" \
    --no-psqlrc --quiet --set ON_ERROR_STOP=1 "$@"
}

failed=()
for t in $TPCDS_LOAD_TABLES; do
  shopt -s nullglob
  files=("$DATA_DIR/$t.dat" "$DATA_DIR/${t}_"*.dat)
  shopt -u nullglob
  [[ ${#files[@]} -gt 0 ]] || { warn "no .dat for $t — skipping"; continue; }

  log "COPY $t (${#files[@]} file(s))"
  if sed 's/|$//' "${files[@]}" \
      | psql_run --command "COPY $t FROM STDIN WITH (FORMAT csv, DELIMITER '|', NULL '')" \
        >"$LOG_DIR/$t.log" 2>&1; then
    rows="$(psql_run --tuples-only --no-align --command "SELECT count(*) FROM $t")"
    ok "$t — $rows rows / 행"
  else
    failed+=("$t")
    warn "$t FAILED — see $LOG_DIR/$t.log / 실패"
    head -3 "$LOG_DIR/$t.log" | sed 's/^/      /' >&2
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  die "COPY failed for: ${failed[*]} / 적재 실패"
fi

# Statistics matter more here than on most engines: without them the planner will
# pick nested loops for the large fact joins and several queries become unusable.
# 통계는 다른 엔진보다 특히 중요합니다. 통계가 없으면 플래너가 대형 팩트 조인에
# 중첩 루프를 선택해 일부 쿼리가 사실상 실행 불가해집니다.
log "ANALYZE (required before querying / 쿼리 전 필수)"
psql_run --command "ANALYZE" >/dev/null
ok "ANALYZE complete / 완료"
