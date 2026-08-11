#!/usr/bin/env bash
#
# ClickHouse loader — INSERT ... FORMAT CSV over the client, per table.
# ClickHouse 로더 — 테이블별로 클라이언트를 통해 INSERT ... FORMAT CSV.
#
# The .dat files use '|' as the delimiter and end every line with one, which
# CSV-with-custom-delimiter reads as a trailing empty field. The trailing
# delimiter is stripped on the way in rather than rewriting the generated files.
# .dat 파일은 '|' 를 구분자로 쓰고 각 줄 끝에도 구분자가 있어, 사용자 지정
# 구분자 CSV 로 읽으면 마지막에 빈 필드가 생깁니다. 생성 파일을 수정하지 않고
# 적재 중에 제거합니다.
#
# input_format_null_as_default lets empty fields become the column default, which
# is what dsdgen means by an empty field in a non-Nullable column.
# input_format_null_as_default 로 빈 필드가 컬럼 기본값이 되도록 합니다. dsdgen 이
# non-Nullable 컬럼에서 빈 필드로 표현하는 의미와 일치합니다.
#
# Invoked by bin/load.sh, which exports DATA_DIR, LOG_DIR and TPCDS_LOAD_TABLES.
# bin/load.sh 가 DATA_DIR, LOG_DIR, TPCDS_LOAD_TABLES 를 export 한 뒤 호출합니다.
#
set -euo pipefail
source "$REPO_ROOT/bin/lib/common.sh"

require_cmd clickhouse-client "ClickHouse client"

ch() {
  # shellcheck disable=SC2086  # CH_EXTRA_ARGS is intentionally word-split
  clickhouse-client --host "${CH_HOST:-localhost}" --port "${CH_PORT:-9000}" \
    --user "${CH_USER:-default}" --password "${CH_PASSWORD:-}" \
    --database "${CH_DATABASE:-tpcds}" ${CH_EXTRA_ARGS:-} "$@"
}

failed=()
for t in $TPCDS_LOAD_TABLES; do
  mapfile -t files < <(data_files "$DATA_DIR" "$t")
  [[ ${#files[@]} -gt 0 ]] || { warn "no .dat for $t — skipping"; continue; }

  log "INSERT $t (${#files[@]} file(s))"
  if sed 's/|$//' "${files[@]}" \
      | ch --query "INSERT INTO $t FORMAT CSV" \
           --format_csv_delimiter='|' \
           --input_format_defaults_for_omitted_fields=1 \
           --input_format_null_as_default=1 \
           --date_time_input_format=best_effort \
        >"$LOG_DIR/$t.log" 2>&1; then
    rows="$(ch --query "SELECT count() FROM $t")"
    ok "$t — $rows rows / 행"
  else
    failed+=("$t")
    warn "$t FAILED — see $LOG_DIR/$t.log / 실패"
    head -3 "$LOG_DIR/$t.log" | sed 's/^/      /' >&2
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  die "INSERT failed for: ${failed[*]} / 적재 실패"
fi

# ClickHouse merges in the background; forcing it now means the first query run is
# not competing with merge activity for I/O.
# ClickHouse 는 백그라운드에서 머지합니다. 지금 강제하면 첫 쿼리 실행이 머지와
# I/O 를 경합하지 않습니다.
if [[ "${CH_OPTIMIZE_AFTER_LOAD:-1}" == "1" ]]; then
  log "OPTIMIZE TABLE ... FINAL (set CH_OPTIMIZE_AFTER_LOAD=0 to skip / 건너뛰려면 0)"
  for t in $TPCDS_LOAD_TABLES; do
    ch --query "OPTIMIZE TABLE $t FINAL" --receive_timeout 3600 >/dev/null 2>&1 \
      || warn "OPTIMIZE $t did not complete — harmless, merges continue in background
               OPTIMIZE 미완료 — 무해하며 백그라운드 머지가 계속됩니다"
  done
  ok "optimize pass done / 완료"
fi
