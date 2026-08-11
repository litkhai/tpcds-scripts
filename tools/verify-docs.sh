#!/usr/bin/env bash
#
# verify-docs.sh — Build the documentation site and check it in a real browser.
#                  문서 사이트를 빌드하고 실제 브라우저에서 검사합니다.
#
# Everything runs in containers: MkDocs, nginx and headless Chromium. Nothing is
# installed on the host, and no local python, node or browser is required.
# 모든 것이 컨테이너에서 실행됩니다. MkDocs, nginx, 헤드리스 Chromium 모두 그렇습니다.
# 호스트에는 아무것도 설치하지 않으며 로컬 python, node, 브라우저가 필요하지 않습니다.
#
# Grepping the built HTML proves the markup exists; it cannot prove that mermaid draws,
# that the copy buttons appear, that the Korean font resolves, or that dark mode works.
# Those are client-side, so this drives a browser and asserts against the live DOM.
# 빌드된 HTML 을 grep 하면 마크업 존재는 증명되지만, mermaid 렌더링·복사 버튼·한글 폰트
# 적용·다크 모드 동작은 증명할 수 없습니다. 모두 클라이언트 사이드이므로 브라우저를
# 구동해 실제 DOM 에 대해 검사합니다.
#
# Usage / 사용법:
#   tools/verify-docs.sh            # build, serve, check, write screenshots
#   tools/verify-docs.sh --keep     # leave the site served for browsing
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/lib/common.sh"

PORT="${DOCS_PORT:-8099}"
SHOTS="$REPO_ROOT/results/docs-screenshots"
KEEP=0
[[ "${1:-}" == "--keep" ]] && KEEP=1

DOCS_IMAGE="tpcds-docs-build"
BROWSER_IMAGE="mcr.microsoft.com/playwright:v1.49.1-noble"
SERVE_NAME="tpcds-docs-serve"

require_cmd docker
docker info >/dev/null 2>&1 || die "the docker daemon is not reachable / docker 데몬에 접근할 수 없습니다"

cleanup() {
  [[ $KEEP -eq 1 ]] && { dim "site left served at http://127.0.0.1:$PORT (docker rm -f $SERVE_NAME)"; return; }
  docker rm -f "$SERVE_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
log "building the docs image / 문서 이미지 빌드"
docker build -q -t "$DOCS_IMAGE" -f - "$REPO_ROOT" >/dev/null <<'DOCKERFILE'
FROM python:3.12-slim
COPY requirements-docs.txt /r.txt
RUN pip install --quiet --no-cache-dir -r /r.txt
DOCKERFILE

# --strict turns a broken internal link into a build failure.
# --strict 는 깨진 내부 링크를 빌드 실패로 처리합니다.
log "mkdocs build --strict"
docker run --rm -v "$REPO_ROOT:/w" -w /w "$DOCS_IMAGE" mkdocs build --strict 2>&1 \
  | grep -E 'INFO|WARNING|ERROR' | sed 's/^/    /' || true
[[ -f "$REPO_ROOT/site/index.html" ]] || die "the build produced no site/ output"

log "serving site/ on port $PORT"
docker rm -f "$SERVE_NAME" >/dev/null 2>&1 || true
docker run -d --name "$SERVE_NAME" \
  -v "$REPO_ROOT/site:/usr/share/nginx/html:ro" \
  -p "$PORT:80" nginx:alpine >/dev/null
for i in $(seq 1 30); do
  docker run --rm --network host curlimages/curl:latest \
    -sf -o /dev/null "http://127.0.0.1:$PORT/" && break
  [[ $i -eq 30 ]] && die "nginx did not start serving the site / 사이트 서빙 실패"
  sleep 1
done
ok "site reachable / 사이트 접근 가능"

mkdir -p "$SHOTS"
rm -f "$SHOTS"/*.png

log "checking in headless Chromium / 헤드리스 Chromium 검사"
echo
# The Playwright image ships the browsers but not the npm package, so install it into a
# throwaway directory inside the container.
# Playwright 이미지에는 브라우저는 있지만 npm 패키지가 없으므로, 컨테이너 내부의 임시
# 디렉터리에 설치합니다.
set +e
# The script is mounted inside the working directory so that node resolves
# playwright from /work/node_modules; mounted at / it would look in /node_modules.
# 스크립트를 작업 디렉터리 안에 마운트해 node 가 /work/node_modules 에서 playwright 를
# 찾도록 합니다. / 에 마운트하면 /node_modules 를 찾습니다.
docker run --rm --network host \
  -v "$REPO_ROOT/tools/verify-docs.js:/work/verify.js:ro" \
  -v "$SHOTS:/shots" \
  -e "DOCS_URL=http://127.0.0.1:$PORT" \
  -e SHOT_DIR=/shots \
  -w /work "$BROWSER_IMAGE" \
  bash -c 'npm install --no-save --no-audit --no-fund playwright@1.49.1 2>&1 | tail -2
           node verify.js'
status=$?
set -e

echo
if [[ $status -eq 0 ]]; then
  ok "all browser checks passed / 브라우저 검사 전체 통과"
else
  warn "browser checks reported failures (exit $status) / 브라우저 검사 실패 있음"
fi
log "screenshots → ${SHOTS#"$REPO_ROOT"/}"
ls -1 "$SHOTS" 2>/dev/null | sed 's/^/    /' || true

exit $status
