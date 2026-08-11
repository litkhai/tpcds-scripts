#!/usr/bin/env bash
#
# StarRocks loader — Stream Load over HTTP against the FE.
# StarRocks 로더 — FE 에 HTTP Stream Load.
#
# Stream Load is the right tool for local files: it is synchronous, returns a JSON
# status per request, and needs no broker. The FE replies with a 307 redirect to a
# BE, so curl must be allowed to follow it and re-send the body (--location-trusted).
# Stream Load 는 로컬 파일 적재에 적합합니다. 동기식이고 요청당 JSON 상태를
# 반환하며 broker 가 필요 없습니다. FE 가 BE 로 307 리다이렉트하므로 curl 이
# 이를 따라가며 본문을 재전송하도록 --location-trusted 가 필요합니다.
#
# Invoked by bin/load.sh, which exports DATA_DIR, LOG_DIR and TPCDS_LOAD_TABLES.
# bin/load.sh 가 DATA_DIR, LOG_DIR, TPCDS_LOAD_TABLES 를 export 한 뒤 호출합니다.
#
set -euo pipefail
source "$REPO_ROOT/bin/lib/common.sh"

require_cmd curl
require_cmd mysql "mysql client — StarRocks speaks the MySQL protocol"

SR_HOST="${SR_HOST:-127.0.0.1}"
SR_HTTP_PORT="${SR_HTTP_PORT:-8030}"
SR_USER="${SR_USER:-root}"
SR_PASSWORD="${SR_PASSWORD:-}"
SR_DATABASE="${SR_DATABASE:-tpcds}"

sr_query() {
  mysql --host "$SR_HOST" --port "${SR_PORT:-9030}" --user "$SR_USER" \
    ${SR_PASSWORD:+--password="$SR_PASSWORD"} --database "$SR_DATABASE" \
    --batch --raw --skip-column-names --execute "$1"
}

# A single scratch file holds the delimiter-stripped copy of whichever .dat is being
# sent, so the generated files are never modified in place.
# 전송 중인 .dat 의 구분자 제거 사본을 담는 임시 파일 하나를 사용하며, 생성된 파일은
# 원본 그대로 유지합니다.
STAGED="$(mktemp)"
trap 'rm -f "$STAGED"' EXIT

failed=()
for t in $TPCDS_LOAD_TABLES; do
  mapfile -t files < <(data_files "$DATA_DIR" "$t")
  [[ ${#files[@]} -gt 0 ]] || { warn "no .dat for $t — skipping"; continue; }

  # Map fields by name, not by position. StarRocks requires the duplicate-key columns
  # to lead the table, so its CREATE TABLE reorders all six fact tables relative to the
  # TPC-DS field order that dsdgen writes. Without this header the load either fails on
  # a NOT NULL column or, worse, succeeds with values in the wrong columns.
  # 필드를 위치가 아니라 이름으로 매핑합니다. StarRocks 는 duplicate-key 컬럼이 테이블
  # 앞에 와야 하므로, CREATE TABLE 이 6개 팩트 테이블 전부를 dsdgen 이 기록하는 TPC-DS
  # 필드 순서와 다르게 재배열합니다. 이 헤더가 없으면 NOT NULL 컬럼에서 실패하거나, 더
  # 나쁘게는 값이 잘못된 컬럼에 들어간 채로 성공합니다.
  columns="$(canonical_columns "$t")"
  [[ -n "$columns" ]] || die "cannot determine the column order for $t / 컬럼 순서를 확인할 수 없습니다"

  table_failed=0
  for f in "${files[@]}"; do
    # A label makes the load idempotent: replaying the same file is rejected as a
    # duplicate instead of double-inserting.
    # 레이블을 쓰면 적재가 멱등해집니다. 같은 파일을 재실행하면 중복으로 거부되어
    # 이중 삽입을 막습니다.
    label="tpcds_${t}_$(basename "$f" .dat)_$(cksum < "$f" | awk '{print $1}')"
    log "stream load $t ← $(basename "$f")"

    # dsdgen ends every line with the delimiter, which Stream Load counts as one extra
    # column: every row is rejected with "Target column count doesn't match source value
    # column count" and the request reports "too many filtered rows". Strip it first.
    # dsdgen 은 각 줄 끝에 구분자를 붙이는데, Stream Load 는 이를 추가 컬럼으로 계산해 모든
    # 행이 "Target column count doesn't match source value column count" 로 거부되고
    # "too many filtered rows" 로 보고됩니다. 먼저 제거합니다.
    sed 's/|$//' "$f" > "$STAGED"

    # -T sends an HTTP PUT with a known Content-Length, which is what Stream Load
    # requires. --data-binary would send a POST and the FE answers
    # {"status":"FAILED","msg":"Not implemented"}; piping from stdin makes curl use
    # chunked encoding, which Stream Load also rejects.
    # -T 는 Content-Length 가 확정된 HTTP PUT 을 보내며, Stream Load 가 요구하는 방식입니다.
    # --data-binary 는 POST 를 보내 FE 가 {"status":"FAILED","msg":"Not implemented"} 로
    # 응답하고, stdin 파이프는 curl 이 chunked 인코딩을 쓰게 해 역시 거부됩니다.
    resp="$(curl --silent --show-error --location-trusted \
      --user "$SR_USER:$SR_PASSWORD" \
      --header "label:$label" \
      --header "column_separator:|" \
      --header "columns:$columns" \
      --header "Expect:100-continue" \
      --header "max_filter_ratio:0" \
      --upload-file "$STAGED" \
      "http://$SR_HOST:$SR_HTTP_PORT/api/$SR_DATABASE/$t/_stream_load" 2>&1)" || true

    printf '%s\n' "$resp" >> "$LOG_DIR/$t.log"
    # The BE reports "Status"; a request the FE rejects outright answers with a
    # lowercase "status" plus "msg", so both shapes are read before deciding.
    # BE 는 "Status" 를 보고하지만, FE 가 요청 자체를 거부하면 소문자 "status" 와 "msg" 로
    # 응답하므로 판단 전에 두 형태를 모두 확인합니다.
    status="$(printf '%s' "$resp" | sed -n 's/.*"Status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    if [[ -z "$status" ]]; then
      status="$(printf '%s' "$resp" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
      [[ -n "$status" ]] && status="$status: $(printf '%s' "$resp" | sed -n 's/.*"msg"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    fi
    case "$status" in
      Success|Publish\ Timeout) ;;
      *)
        table_failed=1
        warn "$t ← $(basename "$f"): Status=${status:-<none>} — see $LOG_DIR/$t.log"
        printf '%s\n' "$resp" | head -3 | sed 's/^/      /' >&2
        ;;
    esac
  done

  if [[ $table_failed -eq 1 ]]; then
    failed+=("$t")
  else
    ok "$t — $(sr_query "SELECT count(*) FROM $t") rows / 행"
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  die "stream load failed for: ${failed[*]} / 적재 실패"
fi

# StarRocks collects statistics automatically, but an explicit pass right after a
# bulk load avoids the first queries planning against stale estimates.
# StarRocks 는 통계를 자동 수집하지만, 벌크 적재 직후 명시적으로 수집하면 첫
# 쿼리들이 오래된 추정치로 계획되는 것을 피할 수 있습니다.
log "ANALYZE TABLE (required before querying / 쿼리 전 권장)"
for t in $TPCDS_LOAD_TABLES; do
  sr_query "ANALYZE TABLE $t" >/dev/null 2>&1 \
    || warn "ANALYZE $t did not complete / 미완료"
done
ok "statistics collected / 통계 수집 완료"
