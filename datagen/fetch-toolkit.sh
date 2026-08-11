#!/usr/bin/env bash
#
# fetch-toolkit.sh — Obtain and build the TPC-DS data generator (dsdgen).
#                    TPC-DS 데이터 생성기(dsdgen)를 받아 빌드합니다.
#
# WHY THIS SCRIPT DOES NOT VENDOR THE TOOLKIT
# 이 스크립트가 툴킷을 리포에 포함하지 않는 이유
#
# The TPC-DS toolkit — dsdgen, dsqgen, the query templates and the answer sets —
# is TPC copyrighted material distributed under the TPC End User Licensing
# Agreement, not an open-source licence. The EULA governs redistribution, so this
# repository does not carry a copy: you accept the EULA and download it yourself,
# or point this script at a checkout you already have.
# TPC-DS 툴킷(dsdgen, dsqgen, 쿼리 템플릿, 정답 세트)은 오픈소스 라이선스가 아닌
# TPC End User Licensing Agreement 로 배포되는 TPC 저작물입니다. EULA 가 재배포를
# 규율하므로 이 리포지토리는 사본을 포함하지 않습니다. 직접 EULA 에 동의하고
# 내려받거나, 이미 보유한 체크아웃 경로를 이 스크립트에 지정하십시오.
#
# Two routes / 두 가지 방법:
#
#   1. Official  / 공식: https://www.tpc.org/tpcds/  → "Download TPC-DS Tools"
#      Accept the EULA, unzip, then run this script with --from <dir>.
#      EULA 에 동의하고 압축을 풀어 --from <dir> 로 실행하십시오.
#
#   2. Community / 커뮤니티: https://github.com/gregrahn/tpcds-kit
#      A widely used fork carrying patches that let the toolkit build on modern
#      Linux and macOS. It ships EULA.txt and NO open-source licence — the TPC
#      terms still apply to what you download.
#      최신 Linux/macOS 에서 빌드되도록 패치한 널리 쓰이는 포크입니다. EULA.txt 만
#      있고 오픈소스 라이선스는 없으므로, 내려받은 결과물에도 TPC 조건이 적용됩니다.
#
# Usage / 사용법:
#   datagen/fetch-toolkit.sh --community        # clone + build the community fork
#   datagen/fetch-toolkit.sh --from ~/tpcds-kit # build from a checkout you have
#   datagen/fetch-toolkit.sh --check            # just report what is present
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/lib/common.sh"

TOOLKIT_DIR="${TPCDS_TOOLKIT_DIR:-$REPO_ROOT/.toolkit}"
MODE=""
FROM=""

usage() {
  cat <<'EOF'
Usage / 사용법: datagen/fetch-toolkit.sh <mode>

  --community      clone github.com/gregrahn/tpcds-kit and build dsdgen/dsqgen
                   gregrahn/tpcds-kit 을 clone 하고 dsdgen/dsqgen 빌드
  --from <dir>     build from an existing toolkit checkout
                   기존 툴킷 체크아웃에서 빌드
  --check          report whether a built dsdgen is available
                   빌드된 dsdgen 존재 여부 확인
  -h, --help       show this help / 도움말

The toolkit lands in .toolkit/ which is git-ignored, so nothing under the TPC EULA
is ever committed. Override with TPCDS_TOOLKIT_DIR.
툴킷은 git 에서 제외되는 .toolkit/ 에 위치하므로 TPC EULA 대상 자산이 커밋되지
않습니다. TPCDS_TOOLKIT_DIR 로 위치를 바꿀 수 있습니다.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --community) MODE=community; shift ;;
    --from)      MODE=from; FROM="${2:?}"; shift 2 ;;
    --check)     MODE=check; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           die "unknown argument '$1' — see --help" ;;
  esac
done
[[ -n "$MODE" ]] || { usage; exit 1; }

# dsdgen builds into tools/ inside the toolkit tree.
# dsdgen 은 툴킷 트리의 tools/ 에 빌드됩니다.
dsdgen_path() { printf '%s/tools/dsdgen' "$1"; }

if [[ "$MODE" == "check" ]]; then
  if [[ -x "$(dsdgen_path "$TOOLKIT_DIR")" ]]; then
    ok "dsdgen present: $(dsdgen_path "$TOOLKIT_DIR")"
    exit 0
  fi
  warn "no built dsdgen under $TOOLKIT_DIR"
  warn "run: datagen/fetch-toolkit.sh --community"
  exit 1
fi

build_toolkit() {
  local dir="$1"
  [[ -d "$dir/tools" ]] || die "no tools/ directory in $dir — is this a TPC-DS toolkit checkout?
       $dir 에 tools/ 가 없습니다. TPC-DS 툴킷 체크아웃이 맞습니까?"
  require_cmd make
  require_cmd gcc "a C compiler — install build-essential, or Xcode CLT on macOS"

  log "building dsdgen / dsqgen in $dir/tools"
  # The toolkit's makefile selects platform-specific code paths via OS=.
  # 툴킷 makefile 은 OS= 로 플랫폼별 코드 경로를 선택합니다.
  local os_flag
  case "$(uname -s)" in
    Linux)  os_flag=LINUX ;;
    Darwin) os_flag=MACOS ;;
    *)      die "unsupported platform $(uname -s) — build the toolkit manually / 수동 빌드 필요" ;;
  esac

  ( cd "$dir/tools" && make -s OS="$os_flag" ) \
    || die "toolkit build failed. The upstream makefile is sensitive to compiler
       version; see the toolkit's own README for platform notes.
       툴킷 빌드 실패. 상류 makefile 은 컴파일러 버전에 민감합니다. 툴킷 README 의
       플랫폼 안내를 확인하십시오."

  [[ -x "$(dsdgen_path "$dir")" ]] || die "build reported success but no dsdgen binary at $(dsdgen_path "$dir")"
  ok "dsdgen built: $(dsdgen_path "$dir")"
}

case "$MODE" in
  community)
    require_cmd git
    cat <<'EOF'

  You are about to download the TPC-DS toolkit from github.com/gregrahn/tpcds-kit.
  That repository contains EULA.txt and no open-source licence: the TPC End User
  Licensing Agreement governs your use of what you are about to fetch. Read it
  before using the generated data for anything you publish.

  이제 github.com/gregrahn/tpcds-kit 에서 TPC-DS 툴킷을 내려받습니다. 해당
  리포지토리에는 EULA.txt 만 있고 오픈소스 라이선스가 없으며, 내려받는 자산의
  사용은 TPC End User Licensing Agreement 를 따릅니다. 생성한 데이터를 공개
  목적으로 사용하기 전에 반드시 읽어보십시오.

EOF
    read -r -p "  Continue? / 계속하시겠습니까? [y/N] " reply
    [[ "$reply" == [yY]* ]] || die "aborted / 취소됨"

    if [[ -d "$TOOLKIT_DIR/.git" ]]; then
      log "toolkit already cloned at $TOOLKIT_DIR — reusing / 이미 clone 되어 있어 재사용"
    else
      mkdir -p "$(dirname "$TOOLKIT_DIR")"
      git clone --depth 1 https://github.com/gregrahn/tpcds-kit.git "$TOOLKIT_DIR"
    fi
    build_toolkit "$TOOLKIT_DIR"
    ;;
  from)
    [[ -d "$FROM" ]] || die "no such directory: $FROM"
    FROM="$(cd "$FROM" && pwd)"
    build_toolkit "$FROM"
    log "use it with: TPCDS_TOOLKIT_DIR=$FROM datagen/generate.sh --sf 1 --out <dir>"
    ;;
esac

echo
log "next / 다음 단계: datagen/generate.sh --sf 1 --out /data/tpcds/sf1"
