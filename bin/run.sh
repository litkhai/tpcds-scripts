#!/usr/bin/env bash
#
# run.sh — Execute the TPC-DS query set against one engine and record timings.
#          TPC-DS 쿼리 세트를 하나의 엔진에 실행하고 수행 시간을 기록합니다.
#
# Timing is wall-clock around the engine's own CLI, measured by this script.
# It therefore includes client round-trip and result transfer, which is what a
# user experiences. It is not the TPC-DS reported metric (QphDS@SF) and results
# are not comparable to published TPC-DS results — see NOTICE.md.
# 시간 측정은 각 엔진 CLI 호출을 감싼 실측(wall-clock) 시간이므로 클라이언트
# 왕복과 결과 전송이 포함됩니다. TPC-DS 공식 지표(QphDS@SF)가 아니며 공표된
# TPC-DS 결과와 비교할 수 없습니다. NOTICE.md 참고.
#
# Usage / 사용법:
#   bin/run.sh --engine postgres
#   bin/run.sh --engine clickhouse --queries 1,5,22 --iterations 3
#   bin/run.sh --engine oracle --queries 1-10 --warmup 1 --sf 100
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

ENGINE=""
QUERIES="all"
ITERATIONS=1
WARMUP=0
SF="${TPCDS_SF:-unknown}"
OUT=""
KEEP_OUTPUT=0
CONTINUE_ON_ERROR=0

usage() {
  cat <<'EOF'
Usage / 사용법: bin/run.sh --engine <engine> [options]

  --engine <name>      oracle | postgres | vertica | clickhouse | starrocks | duckdb (required / 필수)
  --queries <spec>     all (default) | 1,5,22 | 1-10 | 14_2        쿼리 선택
  --iterations <n>     measured runs per query, default 1          쿼리별 측정 횟수
  --warmup <n>         unmeasured runs before measuring, default 0 측정 전 예열 횟수
  --sf <n>             scale factor, recorded in the results only  스케일 팩터(기록용)
  --out <file>         results CSV path                            결과 CSV 경로
  --keep-output        keep each query's result rows under results/ 쿼리 결과 행 보관
  --continue-on-error  do not stop at the first failing query       실패해도 계속 진행
  -h, --help           show this help                              도움말

Connection settings come from config/<engine>.env — copy the .example first.
접속 설정은 config/<engine>.env 에서 읽습니다. 먼저 .example 을 복사하세요.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine)            ENGINE="${2:?}"; shift 2 ;;
    --queries)           QUERIES="${2:?}"; shift 2 ;;
    --iterations)        ITERATIONS="${2:?}"; shift 2 ;;
    --warmup)            WARMUP="${2:?}"; shift 2 ;;
    --sf)                SF="${2:?}"; shift 2 ;;
    --out)               OUT="${2:?}"; shift 2 ;;
    --keep-output)       KEEP_OUTPUT=1; shift ;;
    --continue-on-error) CONTINUE_ON_ERROR=1; shift ;;
    -h|--help)           usage; exit 0 ;;
    *)                   die "unknown argument '$1' — see --help" ;;
  esac
done

require_engine "$ENGINE"
load_config "$ENGINE"

RUN_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
: "${OUT:=$REPO_ROOT/results/${RUN_STAMP}-${ENGINE}-sf${SF}.csv}"
mkdir -p "$(dirname "$OUT")"
OUTPUT_DIR="$REPO_ROOT/results/${RUN_STAMP}-${ENGINE}-sf${SF}-output"
[[ $KEEP_OUTPUT -eq 1 ]] && mkdir -p "$OUTPUT_DIR"

# ---------------------------------------------------------------------------
# engine_exec and check_client come from bin/lib/common.sh.
# engine_exec 와 check_client 는 bin/lib/common.sh 에서 제공됩니다.
exec_query() { engine_exec "$ENGINE"; }

check_client "$ENGINE"

# A read loop rather than mapfile: DuckDB runs on the host, and macOS ships bash 3.2,
# which has no mapfile.
# mapfile 대신 read 루프를 사용합니다. DuckDB 는 호스트에서 실행되고 macOS 는 mapfile 이
# 없는 bash 3.2 를 제공합니다.
QUERY_FILES=()
while IFS= read -r qf; do QUERY_FILES+=("$qf"); done < <(resolve_queries "$ENGINE" "$QUERIES")
[[ ${#QUERY_FILES[@]} -gt 0 ]] || die "no queries matched '$QUERIES'"

log "engine=$ENGINE  queries=${#QUERY_FILES[@]}  iterations=$ITERATIONS  warmup=$WARMUP  sf=$SF"
log "results → ${OUT#"$REPO_ROOT"/}"

printf 'run_stamp,engine,scale_factor,query,iteration,elapsed_ms,rows,status\n' > "$OUT"

total_fail=0
for qf in "${QUERY_FILES[@]}"; do
  label="$(query_label "$qf")"
  sql="$(strip_comments "$qf")"

  for (( w = 1; w <= WARMUP; w++ )); do
    printf '%s' "$sql" | exec_query >/dev/null 2>&1 || true
  done

  for (( it = 1; it <= ITERATIONS; it++ )); do
    tmp_out="$(mktemp)"; tmp_err="$(mktemp)"
    start="$(now_ms)"
    if printf '%s' "$sql" | exec_query >"$tmp_out" 2>"$tmp_err"; then
      elapsed=$(( $(now_ms) - start ))
      rows="$(grep -c . "$tmp_out" || true)"
      printf '%s,%s,%s,%s,%s,%s,%s,ok\n' \
        "$RUN_STAMP" "$ENGINE" "$SF" "$label" "$it" "$elapsed" "$rows" >> "$OUT"
      printf '  q%-6s iter %-2s %8s ms  %6s rows\n' "$label" "$it" "$elapsed" "$rows"
      if [[ $KEEP_OUTPUT -eq 1 && $it -eq 1 ]]; then
        cp "$tmp_out" "$OUTPUT_DIR/query$label.out"
      fi
    else
      elapsed=$(( $(now_ms) - start ))
      total_fail=$((total_fail + 1))
      printf '%s,%s,%s,%s,%s,%s,,error\n' \
        "$RUN_STAMP" "$ENGINE" "$SF" "$label" "$it" "$elapsed" >> "$OUT"
      printf '  q%-6s iter %-2s %8s ms  %sFAILED%s\n' "$label" "$it" "$elapsed" "$C_ERR" "$C_RESET"
      head -3 "$tmp_err" | sed 's/^/      /' >&2
      [[ $CONTINUE_ON_ERROR -eq 1 ]] || { rm -f "$tmp_out" "$tmp_err"; die "stopping at q$label (use --continue-on-error to keep going)"; }
    fi
    rm -f "$tmp_out" "$tmp_err"
  done
done

echo
if [[ $total_fail -eq 0 ]]; then
  ok "all ${#QUERY_FILES[@]} queries succeeded / 전체 성공"
else
  warn "$total_fail execution(s) failed / 실행 실패 $total_fail 건"
fi
log "wrote ${OUT#"$REPO_ROOT"/}"
[[ $total_fail -eq 0 ]]
