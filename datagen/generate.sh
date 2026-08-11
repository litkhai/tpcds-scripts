#!/usr/bin/env bash
#
# generate.sh — Produce TPC-DS flat files at a given scale factor.
#               지정한 스케일 팩터로 TPC-DS 플랫 파일을 생성합니다.
#
# Requires a built toolkit; see fetch-toolkit.sh. Nothing under the TPC EULA is
# stored in this repository.
# 빌드된 툴킷이 필요합니다. fetch-toolkit.sh 참고. TPC EULA 대상 자산은 이
# 리포지토리에 저장되지 않습니다.
#
# Usage / 사용법:
#   datagen/generate.sh --sf 1   --out /data/tpcds/sf1
#   datagen/generate.sh --sf 100 --out /data/tpcds/sf100 --parallel 8
#   datagen/generate.sh --sf 100 --out /data/tpcds/sf100 --parallel 8 --tables store_sales
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/lib/common.sh"

TOOLKIT_DIR="${TPCDS_TOOLKIT_DIR:-$REPO_ROOT/.toolkit}"
SF=""
OUT=""
PARALLEL=1
TABLES=""

usage() {
  cat <<'EOF'
Usage / 사용법: datagen/generate.sh --sf <n> --out <dir> [options]

  --sf <n>          scale factor in GB: 1, 10, 100, 1000, 3000, 10000 (required / 필수)
                    스케일 팩터(GB)
  --out <dir>       output directory for the .dat files (required / 필수)
                    .dat 파일 출력 디렉터리
  --parallel <n>    number of dsdgen child processes, default 1
                    dsdgen 자식 프로세스 수(기본 1)
  --tables <spec>   comma-separated table names, default all
                    콤마로 구분한 테이블명(기본 전체)
  --force           overwrite a non-empty output directory
                    비어 있지 않은 출력 디렉터리를 덮어씀
  -h, --help        show this help / 도움말

A scale factor produces roughly that many GB of flat files, and the loaded database
is larger again. Check free space before running SF 1000 or above.
스케일 팩터는 대략 그 GB 만큼의 플랫 파일을 생성하며, 적재된 데이터베이스는 그보다
더 큽니다. SF 1000 이상은 실행 전에 여유 공간을 확인하십시오.

With --parallel N, dsdgen writes <table>_1_N.dat ... <table>_N_N.dat. The loaders
in this repository pick up those chunks automatically.
--parallel N 을 쓰면 dsdgen 이 <table>_1_N.dat ... <table>_N_N.dat 를 생성합니다.
이 리포지토리의 로더는 해당 청크를 자동으로 인식합니다.
EOF
}

FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sf)       SF="${2:?}"; shift 2 ;;
    --out)      OUT="${2:?}"; shift 2 ;;
    --parallel) PARALLEL="${2:?}"; shift 2 ;;
    --tables)   TABLES="${2:?}"; shift 2 ;;
    --force)    FORCE=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *)          die "unknown argument '$1' — see --help" ;;
  esac
done

[[ -n "$SF" ]]  || die "--sf is required / --sf 는 필수입니다"
[[ -n "$OUT" ]] || die "--out is required / --out 는 필수입니다"
[[ "$SF" =~ ^[0-9]+$ ]] || die "--sf must be an integer / 정수여야 합니다"
[[ "$PARALLEL" =~ ^[0-9]+$ && "$PARALLEL" -ge 1 ]] || die "--parallel must be >= 1"

DSDGEN="$TOOLKIT_DIR/tools/dsdgen"
[[ -x "$DSDGEN" ]] || die "no dsdgen at $DSDGEN
       run: datagen/fetch-toolkit.sh --community
       또는: datagen/fetch-toolkit.sh --from <toolkit checkout>"

# dsdgen reads tpcds.idx from its own directory and refuses to run without it.
# dsdgen 은 자신의 디렉터리에서 tpcds.idx 를 읽으며, 없으면 실행을 거부합니다.
IDX="$TOOLKIT_DIR/tools/tpcds.idx"
[[ -f "$IDX" ]] || die "no tpcds.idx next to dsdgen — the toolkit build is incomplete
       dsdgen 옆에 tpcds.idx 가 없습니다. 툴킷 빌드가 완전하지 않습니다"

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
if [[ -n "$(ls -A "$OUT" 2>/dev/null)" && $FORCE -eq 0 ]]; then
  die "output directory is not empty: $OUT (use --force to overwrite)
       출력 디렉터리가 비어 있지 않습니다. 덮어쓰려면 --force 를 사용하십시오"
fi

# TPC-DS only defines the qualification database and the listed scale factors; other
# values generate but are not a valid TPC-DS scale.
# TPC-DS 는 qualification 데이터베이스와 정해진 스케일 팩터만 정의합니다. 다른 값도
# 생성되지만 유효한 TPC-DS 스케일이 아닙니다.
case "$SF" in
  1|10|100|300|1000|3000|10000|30000|100000) ;;
  *) warn "SF $SF is not a TPC-DS defined scale factor (1/10/100/300/1000/3000/10000/…)
         SF $SF 는 TPC-DS 가 정의한 스케일 팩터가 아닙니다" ;;
esac

log "dsdgen  $DSDGEN"
log "scale   SF $SF"
log "output  $OUT"
log "workers $PARALLEL"

dsdgen_args=(-scale "$SF" -dir "$OUT" -force -terminate n)
[[ -n "$TABLES" ]] && dsdgen_args+=(-table "$TABLES")

start="$(now_ms)"
if [[ "$PARALLEL" -eq 1 ]]; then
  # dsdgen resolves tpcds.idx relative to its working directory.
  # dsdgen 은 작업 디렉터리를 기준으로 tpcds.idx 를 찾습니다.
  ( cd "$TOOLKIT_DIR/tools" && "$DSDGEN" "${dsdgen_args[@]}" ) \
    || die "dsdgen failed / 실행 실패"
else
  pids=()
  for (( child = 1; child <= PARALLEL; child++ )); do
    ( cd "$TOOLKIT_DIR/tools" \
      && "$DSDGEN" "${dsdgen_args[@]}" -parallel "$PARALLEL" -child "$child" ) &
    pids+=($!)
  done
  fail=0
  for p in "${pids[@]}"; do wait "$p" || fail=1; done
  [[ $fail -eq 0 ]] || die "at least one dsdgen worker failed / 워커 실패"
fi
elapsed=$(( ($(now_ms) - start) / 1000 ))

files="$(find "$OUT" -name '*.dat' | wc -l | tr -d ' ')"
[[ "$files" -gt 0 ]] || die "dsdgen produced no .dat files / .dat 파일이 생성되지 않았습니다"

ok "generated $files file(s) in ${elapsed}s — $(du -sh "$OUT" | cut -f1) / 생성 완료"
echo
log "next / 다음 단계:"
dim "  bin/ddl.sh  --engine postgres --create-database"
dim "  bin/load.sh --engine postgres --data-dir $OUT"
dim "  bin/run.sh  --engine postgres --sf $SF"
