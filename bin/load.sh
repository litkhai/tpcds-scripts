#!/usr/bin/env bash
#
# load.sh — Load dsdgen output into one engine, using that engine's bulk loader.
#           dsdgen 출력물을 각 엔진의 벌크 로더로 적재합니다.
#
# Dispatches to engines/<engine>/load/load.sh, which receives DATA_DIR, LOG_DIR
# and the table list through the environment.
# engines/<engine>/load/load.sh 로 위임하며, DATA_DIR, LOG_DIR, 테이블 목록을
# 환경변수로 전달합니다.
#
# Usage / 사용법:
#   bin/load.sh --engine postgres --data-dir /data/tpcds/sf100
#   bin/load.sh --engine oracle --data-dir /data/tpcds/sf1 --tables date_dim,item
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

ENGINE=""
DATA_DIR=""
LOG_DIR=""
TABLES_SPEC="all"

usage() {
  cat <<'EOF'
Usage / 사용법: bin/load.sh --engine <engine> --data-dir <dir> [options]

  --engine <name>    oracle | postgres | vertica | clickhouse | starrocks (required / 필수)
  --data-dir <dir>   directory holding the dsdgen .dat files (required / 필수)
                     dsdgen .dat 파일이 있는 디렉터리
  --log-dir <dir>    loader logs / rejected rows, default <data-dir>/../load-logs
                     로더 로그·거부 행 저장 위치
  --tables <spec>    all (default) | comma-separated table names
                     all(기본) | 콤마로 구분한 테이블명
  -h, --help         show this help / 도움말

Tables load dimensions first, then facts, so a run with enforced referential
integrity also succeeds.
차원 테이블을 먼저 적재하므로 참조 정합성을 강제한 경우에도 성공합니다.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine)   ENGINE="${2:?}"; shift 2 ;;
    --data-dir) DATA_DIR="${2:?}"; shift 2 ;;
    --log-dir)  LOG_DIR="${2:?}"; shift 2 ;;
    --tables)   TABLES_SPEC="${2:?}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          die "unknown argument '$1' — see --help" ;;
  esac
done

require_engine "$ENGINE"
[[ -n "$DATA_DIR" ]] || die "--data-dir is required / --data-dir 는 필수입니다"
[[ -d "$DATA_DIR" ]] || die "no such data directory: $DATA_DIR"
DATA_DIR="$(cd "$DATA_DIR" && pwd)"
: "${LOG_DIR:=$DATA_DIR/../load-logs}"
mkdir -p "$LOG_DIR"
LOG_DIR="$(cd "$LOG_DIR" && pwd)"

load_config "$ENGINE"
check_client "$ENGINE"

# Resolve the table list, preserving the dimensions-before-facts order.
# 차원 → 팩트 순서를 유지하며 테이블 목록을 확정합니다.
if [[ "$TABLES_SPEC" == "all" ]]; then
  SELECTED=("${TPCDS_TABLES[@]}")
else
  IFS=',' read -r -a requested <<< "$TABLES_SPEC"
  SELECTED=()
  for t in "${TPCDS_TABLES[@]}"; do
    for r in "${requested[@]}"; do
      [[ "$t" == "$r" ]] && SELECTED+=("$t")
    done
  done
  # Report anything the caller asked for that is not a TPC-DS table.
  # TPC-DS 테이블이 아닌 요청은 오류로 알립니다.
  for r in "${requested[@]}"; do
    found=0
    for t in "${TPCDS_TABLES[@]}"; do [[ "$t" == "$r" ]] && found=1; done
    [[ $found -eq 1 ]] || die "not a TPC-DS table: '$r'"
  done
fi
[[ ${#SELECTED[@]} -gt 0 ]] || die "no tables selected / 선택된 테이블이 없습니다"

# Missing .dat files are a setup mistake worth catching before any load starts.
# .dat 파일 누락은 적재 시작 전에 잡아야 할 설정 오류입니다.
missing=()
for t in "${SELECTED[@]}"; do
  [[ -n "$(data_files "$DATA_DIR" "$t")" ]] || missing+=("$t")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  die "no .dat file for: ${missing[*]} — check --data-dir or re-run datagen/generate.sh
       .dat 파일이 없습니다. --data-dir 를 확인하거나 datagen/generate.sh 를 다시 실행하세요"
fi

LOADER="$(engine_dir "$ENGINE")/load/load.sh"
[[ -x "$LOADER" ]] || [[ -f "$LOADER" ]] || die "missing loader: ${LOADER#"$REPO_ROOT"/}"

log "engine=$ENGINE  tables=${#SELECTED[@]}  data=$DATA_DIR"
log "loader → ${LOADER#"$REPO_ROOT"/}"

export DATA_DIR LOG_DIR REPO_ROOT
export TPCDS_LOAD_TABLES="${SELECTED[*]}"

start="$(now_ms)"
bash "$LOADER"
elapsed=$(( $(now_ms) - start ))

ok "load finished in $((elapsed / 1000))s / 적재 완료"
log "loader logs → $LOG_DIR"
