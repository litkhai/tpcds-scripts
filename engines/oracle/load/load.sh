#!/usr/bin/env bash
#
# Oracle loader — SQL*Loader (sqlldr) driven by the per-table control files in ctl/.
# Oracle 로더 — ctl/ 의 테이블별 컨트롤 파일을 사용하는 SQL*Loader (sqlldr).
#
# The .ctl files hold @DATA_DIR@ / @LOG_DIR@ placeholders because SQL*Loader does
# not expand environment variables. They are rendered into a temporary directory
# for each run, leaving the versioned templates untouched.
# SQL*Loader 는 환경변수를 전개하지 않으므로 .ctl 파일은 @DATA_DIR@ / @LOG_DIR@
# 자리표시자를 사용합니다. 실행마다 임시 디렉터리에 렌더링하며 버전 관리되는
# 템플릿은 수정하지 않습니다.
#
# Invoked by bin/load.sh, which exports DATA_DIR, LOG_DIR and TPCDS_LOAD_TABLES.
# bin/load.sh 가 DATA_DIR, LOG_DIR, TPCDS_LOAD_TABLES 를 export 한 뒤 호출합니다.
#
set -euo pipefail
source "$REPO_ROOT/bin/lib/common.sh"

require_cmd sqlldr "Oracle Instant Client — Tools package"
: "${ORACLE_CONNECT:?set ORACLE_CONNECT in config/oracle.env}"

CTL_DIR="$(dirname "${BASH_SOURCE[0]}")/ctl"
RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$RENDER_DIR"' EXIT

# Direct path load bypasses the buffer cache and is far faster for bulk loads;
# it also skips most redo when the table is NOLOGGING.
# 직접 경로 적재는 버퍼 캐시를 우회해 벌크 적재에 훨씬 빠르며, 테이블이
# NOLOGGING 이면 대부분의 redo 도 건너뜁니다.
SQLLDR_OPTS="${ORACLE_SQLLDR_OPTS:-direct=true parallel=true rows=100000 errors=0}"

failed=()
for t in $TPCDS_LOAD_TABLES; do
  ctl="$CTL_DIR/$t.ctl"
  [[ -f "$ctl" ]] || { warn "no control file for $t — skipping / 컨트롤 파일 없음"; continue; }

  sed -e "s|@DATA_DIR@|$DATA_DIR|g" -e "s|@LOG_DIR@|$LOG_DIR|g" "$ctl" > "$RENDER_DIR/$t.ctl"

  log "sqlldr $t"
  # shellcheck disable=SC2086  # SQLLDR_OPTS is intentionally word-split
  if sqlldr "$ORACLE_CONNECT" \
      control="$RENDER_DIR/$t.ctl" \
      log="$LOG_DIR/$t.log" \
      $SQLLDR_OPTS \
      silent=header,feedback >/dev/null 2>&1; then
    rows="$(grep -oE '^[[:space:]]*[0-9]+ Rows successfully loaded' "$LOG_DIR/$t.log" | grep -oE '[0-9]+' | head -1)"
    ok "$t — ${rows:-?} rows / 행"
  else
    # sqlldr returns 2 for a warning-level completion (e.g. discarded rows), which
    # is still worth surfacing rather than treating as a hard failure.
    # sqlldr 는 경고 수준 완료(예: 일부 행 discard)에 2 를 반환합니다. 완전한
    # 실패로 취급하지 않고 알립니다.
    if grep -q 'Rows successfully loaded' "$LOG_DIR/$t.log" 2>/dev/null; then
      warn "$t completed with warnings — see $LOG_DIR/$t.log / 경고와 함께 완료"
    else
      failed+=("$t")
      warn "$t FAILED — see $LOG_DIR/$t.log / 실패"
    fi
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  die "sqlldr failed for: ${failed[*]} / 적재 실패"
fi
