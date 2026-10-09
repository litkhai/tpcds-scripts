#!/usr/bin/env bash
#
# DuckDB loader — COPY from the dsdgen .dat files into the database file.
# DuckDB 로더 — dsdgen .dat 파일을 COPY 로 데이터베이스 파일에 적재합니다.
#
# dsdgen writes pipe-delimited rows with a trailing delimiter on every line. Unlike
# PostgreSQL's COPY, DuckDB's COPY into an existing table accepts that trailing empty
# field, so the files are read as they are — no `sed 's/|$//'` step. Measured on DuckDB
# 1.5.6 with the verification fixture; see docs/engines/duckdb.md. AUTO_DETECT is off so
# the sniffer cannot guess a different delimiter or type for a small table; the table
# definition decides the types.
# dsdgen 은 파이프 구분 행을 출력하며 각 줄 끝에도 구분자가 붙습니다. PostgreSQL 의 COPY
# 와 달리 DuckDB 는 기존 테이블로의 COPY 에서 이 끝의 빈 필드를 받아들이므로 파일을 그대로
# 읽습니다(`sed 's/|$//'` 단계 없음). 검증 픽스처로 DuckDB 1.5.6 에서 측정했으며
# docs/engines/duckdb.md 를 참고하십시오. AUTO_DETECT 를 꺼서, 작은 테이블에서 sniffer 가
# 다른 구분자나 타입을 추측하지 못하게 하고 테이블 정의가 타입을 정하도록 합니다.
#
# After each table the row count in the database is compared with the number of lines in
# the .dat files, so a load that silently dropped rows fails here.
# 테이블마다 데이터베이스의 행 수를 .dat 파일의 줄 수와 비교하므로, 행을 조용히 잃은
# 적재는 여기서 실패합니다.
#
# Invoked by bin/load.sh, which exports DATA_DIR, LOG_DIR and TPCDS_LOAD_TABLES.
# bin/load.sh 가 DATA_DIR, LOG_DIR, TPCDS_LOAD_TABLES 를 export 한 뒤 호출합니다.
#
set -euo pipefail
source "$REPO_ROOT/bin/lib/common.sh"

require_cmd duckdb "DuckDB CLI — https://duckdb.org/install/"

# sql_quote <path> — a single-quoted SQL string literal.
sql_quote() { printf "'%s'" "${1//\'/\'\'}"; }

failed=()
for t in $TPCDS_LOAD_TABLES; do
  # A read loop, not mapfile: this loader runs on the host, and macOS ships bash 3.2.
  # mapfile 대신 read 루프: 이 로더는 호스트에서 실행되며 macOS 는 bash 3.2 를 제공합니다.
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(data_files "$DATA_DIR" "$t")
  [[ ${#files[@]} -gt 0 ]] || { warn "no .dat for $t — skipping"; continue; }

  log "COPY $t (${#files[@]} file(s))"
  expected="$(cat "${files[@]}" | wc -l | tr -d ' ')"

  sql=""
  for f in "${files[@]}"; do
    sql+="COPY $t FROM $(sql_quote "$f") (FORMAT csv, DELIMITER '|', HEADER false, NULL '', AUTO_DETECT false);"$'\n'
  done

  if printf '%s' "$sql" | engine_exec duckdb >"$LOG_DIR/$t.log" 2>&1; then
    rows="$(printf 'SELECT count(*) FROM %s;\n' "$t" | engine_exec duckdb)"
    if [[ "$rows" == "$expected" ]]; then
      ok "$t — $rows rows / 행"
    else
      failed+=("$t")
      warn "$t row count $rows != $expected lines in the .dat files / 행 수 불일치"
    fi
  else
    failed+=("$t")
    warn "$t FAILED — see $LOG_DIR/$t.log / 실패"
    head -3 "$LOG_DIR/$t.log" | sed 's/^/      /' >&2
  fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
  die "COPY failed for: ${failed[*]} / 적재 실패"
fi

# No ANALYZE is run. CHECKPOINT folds the write-ahead log into the database file, so the
# file is complete on its own.
# ANALYZE 는 실행하지 않습니다. CHECKPOINT 로 write-ahead log 를 데이터베이스 파일에 합쳐
# 파일이 단독으로 완전해지도록 합니다.
log "CHECKPOINT"
printf 'CHECKPOINT;\n' | engine_exec duckdb >/dev/null
ok "CHECKPOINT complete / 완료"
