#!/usr/bin/env bash
#
# Vertica loader — COPY with DIRECT, one statement per table.
# Vertica 로더 — 테이블별 COPY ... DIRECT.
#
# DIRECT loads straight into ROS containers. On Vertica 12 and later, where the WOS
# was removed, DIRECT is accepted but no longer changes behaviour; it is kept here so
# the script also works against older versions. Rejected rows and their reasons are
# kept per table so a bad load can be diagnosed instead of silently under-counting.
# DIRECT 는 ROS 컨테이너에 직접 적재합니다. WOS 가 제거된 Vertica 12 이상에서는
# 허용되지만 동작에 영향이 없으며, 구버전 호환을 위해 유지합니다. 거부된 행과 사유를
# 테이블별로 남겨, 조용히 행이 누락되는 대신 원인을 진단할 수 있게 합니다.
#
# Invoked by bin/load.sh, which exports DATA_DIR, LOG_DIR and TPCDS_LOAD_TABLES.
# bin/load.sh 가 DATA_DIR, LOG_DIR, TPCDS_LOAD_TABLES 를 export 한 뒤 호출합니다.
#
set -euo pipefail
source "$REPO_ROOT/bin/lib/common.sh"

require_cmd vsql "Vertica client tools"

vsql_run() {
  vsql --host "${VHOST:-localhost}" --port "${VPORT:-5433}" \
    --username "${VUSER:-dbadmin}" --dbname "${VDATABASE:-tpcds}" \
    ${VPASSWORD:+--password "$VPASSWORD"} \
    --no-vsqlrc --quiet --set ON_ERROR_STOP=1 "$@"
}

failed=()
for t in $TPCDS_LOAD_TABLES; do
  shopt -s nullglob
  files=("$DATA_DIR/$t.dat" "$DATA_DIR/${t}_"*.dat)
  shopt -u nullglob
  [[ ${#files[@]} -gt 0 ]] || { warn "no .dat for $t — skipping"; continue; }

  log "COPY $t (${#files[@]} file(s))"
  # Reading from STDIN keeps this working whether vsql runs on the Vertica node or
  # remotely; a server-side COPY would require the files to be on the node.
  # STDIN 으로 읽으면 vsql 이 Vertica 노드에서 실행되든 원격이든 동작합니다.
  # 서버 측 COPY 는 파일이 노드에 있어야 합니다.
  if sed 's/|$//' "${files[@]}" \
      | vsql_run --command "COPY $t FROM STDIN DELIMITER '|' NULL '' \
             REJECTED DATA '$LOG_DIR/$t.rejected' EXCEPTIONS '$LOG_DIR/$t.exceptions' \
             DIRECT ABORT ON ERROR" \
        >"$LOG_DIR/$t.log" 2>&1; then
    rows="$(vsql_run --tuples-only --no-align --command "SELECT count(*) FROM $t")"
    ok "$t — $rows rows / 행"
  else
    failed+=("$t")
    warn "$t FAILED — see $LOG_DIR/$t.log and $LOG_DIR/$t.exceptions / 실패"
    head -3 "$LOG_DIR/$t.log" | sed 's/^/      /' >&2
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  die "COPY failed for: ${failed[*]} / 적재 실패"
fi

# ANALYZE_STATISTICS is what makes Vertica's optimiser choose sane join orders.
# ANALYZE_STATISTICS 가 있어야 Vertica 옵티마이저가 합리적인 조인 순서를 고릅니다.
log "ANALYZE_STATISTICS (required before querying / 쿼리 전 필수)"
for t in $TPCDS_LOAD_TABLES; do
  vsql_run --tuples-only --no-align --command "SELECT ANALYZE_STATISTICS('$t')" >/dev/null
done
ok "statistics collected / 통계 수집 완료"
