#!/usr/bin/env bash
#
# verify.sh — Prove that an engine's schema applies and all 103 queries run.
#             엔진의 스키마가 적용되고 103개 쿼리가 모두 실행되는지 증명합니다.
#
# WHAT THIS PROVES / 무엇을 증명하는가
#
#   ✅ the schema applies on this engine / 스키마가 이 엔진에서 적용된다
#   ✅ every query parses and executes without error, against real rows
#      모든 쿼리가 실제 행에 대해 오류 없이 파싱·실행된다
#   ✅ the loader works end to end / 로더가 처음부터 끝까지 동작한다
#
# WHAT THIS DOES NOT PROVE / 무엇을 증명하지 않는가
#
#   ✖ that answers are correct — the official TPC-DS answer sets are TPC EULA
#     material and are not available here
#     정답이 맞는지 — 공식 TPC-DS 정답 세트는 TPC EULA 자산이라 사용할 수 없다
#   ✖ anything about performance — the fixture is tiny and runs in a container
#     성능에 대한 어떤 것도 — 픽스처는 매우 작고 컨테이너에서 실행된다
#
# The fixture is synthetic data from tools/make-fixture.py, not dsdgen output, so
# this runs without accepting the TPC EULA.
# 픽스처는 dsdgen 출력이 아니라 tools/make-fixture.py 의 합성 데이터이므로 TPC EULA
# 동의 없이 실행됩니다.
#
# Usage / 사용법:
#   tools/verify.sh --engine postgres
#   tools/verify.sh --engine clickhouse --keep      # leave the container running
#   tools/verify.sh --engine duckdb                 # host duckdb CLI, no container
#   tools/verify.sh --all
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)/lib/common.sh"

ENGINE=""
ALL=0
KEEP=0
FIXTURE="${TPCDS_FIXTURE_DIR:-$REPO_ROOT/.fixture}"
REPORT="$REPO_ROOT/results/verification.md"

# Engines this script can drive unattended, i.e. those with a docker profile whose image
# can be pulled anonymously.
#
# Oracle and Vertica are excluded for the same reason: no redistributable image. Oracle
# needs container-registry.oracle.com with a licence acceptance, and there is no public
# Vertica CE image since the OpenText acquisition. Both can still be verified by hand —
# see their pages under docs/engines/.
# 이 스크립트가 무인으로 구동할 수 있는 엔진, 즉 익명으로 이미지를 받을 수 있는 docker
# 프로필을 가진 엔진입니다.
#
# Oracle 과 Vertica 는 같은 이유로 제외됩니다. 재배포 가능한 이미지가 없습니다. Oracle 은
# 라이선스 동의와 함께 container-registry.oracle.com 이 필요하고, OpenText 인수 이후 공개된
# Vertica CE 이미지가 없습니다. 둘 다 수동으로는 검증할 수 있습니다. docs/engines/ 참고.
#
# DuckDB needs no image: it is a command-line tool and a database file. It is verified with
# the duckdb CLI on this host and a temporary database file, and is the one engine here
# that does not need docker.
# DuckDB 는 이미지가 필요 없습니다. 명령줄 도구와 데이터베이스 파일이 전부이므로 이 호스트의
# duckdb CLI 와 임시 데이터베이스 파일로 검증하며, docker 가 필요 없는 유일한 엔진입니다.
VERIFIABLE=(postgres clickhouse starrocks duckdb)

# Engines that need an image the user supplies; verified only when explicitly requested.
# 사용자가 이미지를 제공해야 하는 엔진. 명시적으로 요청할 때만 검증합니다.
BYO_IMAGE=(vertica)

# Known failures that are NOT defects in this repository.
#
# Without this, CI is permanently red for a reason nobody can act on, which trains people
# to ignore it. With it, a run passes when the failures match this list exactly, fails
# when a new query breaks, and warns when a listed query starts passing — so the list
# cannot quietly go stale in either direction.
# 이 저장소의 결함이 **아닌** 알려진 실패 목록입니다.
#
# 이것이 없으면 CI 가 아무도 조치할 수 없는 이유로 영구히 빨간 상태가 되고, 사람들이 CI 를
# 무시하도록 길들입니다. 이 목록이 있으면 실패가 목록과 정확히 일치할 때 통과하고, 새로운
# 쿼리가 깨지면 실패하며, 목록의 쿼리가 통과하기 시작하면 경고합니다. 따라서 목록이 어느
# 방향으로든 조용히 낡아버리지 않습니다.
#
# Record the reason, not just the number. If the reason is an engine bug, link it.
# 숫자만이 아니라 이유를 기록하십시오. 엔진 버그라면 링크를 남기십시오.
expected_failures() {
  case "$1" in
    clickhouse)
      # q61 divides by a count(*) that the verification fixture leaves at 0. It is a
      # fixture-size artifact, not a query or engine defect: the query is correct and
      # runs on a real dataset. Fixing it would mean generating a fixture that satisfies
      # every predicate in all 103 queries, which the fixture does not aim to do.
      # q61 은 검증 픽스처에서 0 이 되는 count(*) 로 나눕니다. 쿼리나 엔진의 결함이 아니라
      # 픽스처 크기에서 오는 현상이며, 쿼리 자체는 정상이고 실제 데이터셋에서는 실행됩니다.
      # 이를 없애려면 103개 쿼리의 모든 조건을 만족하는 픽스처가 필요한데, 픽스처의 목표가
      # 아닙니다.
      printf '61\n'
      ;;
    *) : ;;
  esac
}

expected_reason() {
  case "$1:$2" in
    clickhouse:61) printf 'divides by a count(*) the fixture leaves at 0 / 픽스처에서 0 이 되는 count(*) 로 나눔' ;;
    *)             printf 'see expected_failures() in tools/verify.sh' ;;
  esac
}

usage() {
  cat <<'EOF'
Usage / 사용법: tools/verify.sh --engine <engine> | --all

  --engine <name>   postgres | clickhouse | starrocks | vertica | duckdb
  --all             verify every engine that can run unattended / 무인 실행 가능한 모든 엔진
  --keep            leave the container (duckdb: the database file) afterwards
                    종료 후 컨테이너(duckdb 는 데이터베이스 파일) 유지
  --fixture <dir>   reuse an existing fixture directory / 기존 픽스처 디렉터리 재사용
  -h, --help        show this help / 도움말

--all covers postgres, clickhouse, starrocks and duckdb. duckdb runs with the duckdb CLI on
this host (no container; install it from https://duckdb.org/install/). Oracle and Vertica are excluded
because neither has an anonymously pullable image: Oracle needs
container-registry.oracle.com with a licence acceptance, and no public Vertica CE image
exists since the OpenText acquisition. For Vertica, set VERTICA_IMAGE=<image> and pass
--engine vertica. Otherwise run the steps by hand — see docs/engines/.

--all 은 postgres, clickhouse, starrocks, duckdb 를 대상으로 합니다. duckdb 는 이 호스트의
duckdb CLI 로 실행합니다(컨테이너 없음, https://duckdb.org/install/ 에서 설치). Oracle 과 Vertica 는 익명으로
받을 수 있는 이미지가 없어 제외됩니다. Oracle 은 라이선스 동의와 함께
container-registry.oracle.com 이 필요하고, OpenText 인수 이후 공개된 Vertica CE 이미지가
없습니다. Vertica 는 VERTICA_IMAGE=<image> 를 설정하고 --engine vertica 로 실행하십시오.
그렇지 않으면 수동으로 실행하십시오. docs/engines/ 참고.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine)  ENGINE="${2:?}"; shift 2 ;;
    --all)     ALL=1; shift ;;
    --keep)    KEEP=1; shift ;;
    --fixture) FIXTURE="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)         die "unknown argument '$1' — see --help" ;;
  esac
done
[[ -n "$ENGINE" || $ALL -eq 1 ]] || { usage; exit 1; }

COMPOSE=(docker compose -f "$REPO_ROOT/docker/docker-compose.yml")

# ---------------------------------------------------------------------------
# The client tools live in containers, so verification needs no local psql,
# vsql, clickhouse-client or mysql. Each engine names an image that carries its
# client and can reach the server over the host network.
# 클라이언트 도구가 컨테이너에 있으므로 로컬에 psql, vsql, clickhouse-client, mysql
# 이 필요 없습니다. 각 엔진은 클라이언트를 포함하고 호스트 네트워크로 서버에 접근할 수
# 있는 이미지를 지정합니다.
# ---------------------------------------------------------------------------
client_image() {
  case "$1" in
    postgres)   printf 'postgres:16' ;;
    clickhouse) printf 'clickhouse/clickhouse-server:latest' ;;
    starrocks)  printf 'mysql:8' ;;
    vertica)    printf '%s' "${VERTICA_IMAGE:?set VERTICA_IMAGE}" ;;
  esac
}

# Some client images need extra packages to run our scripts.
# 일부 클라이언트 이미지는 스크립트 실행을 위해 추가 패키지가 필요합니다.
client_prep() {
  case "$1" in
    starrocks) printf 'command -v curl >/dev/null || (microdnf install -y curl >/dev/null 2>&1 || true);' ;;
    *)         printf '' ;;
  esac
}

# Where the repository and the fixture are, as seen by the client. In a container they are
# mounted at /repo and /fixture; for duckdb the client is this host.
# 클라이언트에서 본 저장소와 픽스처의 위치. 컨테이너에서는 /repo, /fixture 에 마운트되고,
# duckdb 는 클라이언트가 이 호스트입니다.
repo_path()    { if [[ "$1" == duckdb ]]; then printf '%s' "$REPO_ROOT"; else printf '/repo'; fi; }
fixture_path() { if [[ "$1" == duckdb ]]; then printf '%s' "$FIXTURE"; else printf '/fixture'; fi; }

in_client() {
  local engine="$1" script="$2"
  if [[ "$engine" == duckdb ]]; then
    # DUCKDB_DATABASE is set by verify_duckdb_setup and wins over any config/duckdb.env.
    # DUCKDB_DATABASE 는 verify_duckdb_setup 이 설정하며 config/duckdb.env 보다 우선합니다.
    ( cd "$REPO_ROOT" && bash -c "$script" )
    return
  fi
  docker run --rm --network host \
    -v "$REPO_ROOT:/repo" -v "$FIXTURE:/fixture" -w /repo \
    --entrypoint /bin/bash \
    "$(client_image "$engine")" -c "$(client_prep "$engine") $script"
}

wait_healthy() {
  local engine="$1" limit="${2:-180}" name="tpcds-$engine"
  log "waiting for $name to become healthy (up to ${limit}s) / 헬스체크 대기"
  local i status
  for (( i = 0; i < limit; i++ )); do
    status="$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo missing)"
    [[ "$status" == "healthy" ]] && { ok "$name healthy after ${i}s"; return 0; }
    if [[ "$status" == "missing" ]]; then
      docker ps -a --filter "name=$name" --format '{{.Status}}' | head -1
      die "$name is not running / 컨테이너가 실행되지 않았습니다"
    fi
    sleep 1
  done
  docker logs --tail 30 "$name" 2>&1 | sed 's/^/    /'
  die "$name did not become healthy within ${limit}s / 시간 내에 healthy 상태가 되지 않았습니다"
}

# Per-engine settings this script must write so the containerised client connects
# to the server on the host network rather than to "localhost" inside itself.
# 컨테이너 클라이언트가 자기 안의 "localhost" 가 아니라 호스트 네트워크의 서버에
# 접속하도록 이 스크립트가 기록해야 하는 엔진별 설정.
write_config() {
  local engine="$1" f="$REPO_ROOT/config/$engine.env"
  if [[ -f "$f" ]]; then
    warn "using existing config/$engine.env / 기존 설정 사용"
    return
  fi
  cp "$REPO_ROOT/config/$engine.env.example" "$f"
  # The examples use localhost, which is correct on the host network.
  # 예시 파일이 localhost 를 사용하며 호스트 네트워크에서 올바릅니다.
  case "$engine" in
    postgres)   sed -i.bak 's/^PGHOST=.*/PGHOST=127.0.0.1/' "$f" ;;
    clickhouse) sed -i.bak 's/^CH_HOST=.*/CH_HOST=127.0.0.1/' "$f" ;;
    starrocks)  sed -i.bak 's/^SR_HOST=.*/SR_HOST=127.0.0.1/' "$f" ;;
    vertica)    sed -i.bak 's/^VHOST=.*/VHOST=127.0.0.1/' "$f" ;;
  esac
  rm -f "$f.bak"
  dim "wrote config/$engine.env"
}

needs_create_db() {
  case "$1" in
    postgres|clickhouse|starrocks) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
verify_one() {
  local engine="$1"
  local start_ts; start_ts="$(now_ms)"

  printf '\n%s══════════════════════════════════════════════════════════%s\n' "$C_INFO" "$C_RESET"
  printf '%s  Verifying %s%s\n' "$C_INFO" "$engine" "$C_RESET"
  printf '%s══════════════════════════════════════════════════════════%s\n' "$C_INFO" "$C_RESET"

  local schema_res="—" load_res="—" query_res="—" pass=0 fail=0 rows_total=0
  local rp fp load_logs=/tmp/vl duck_dir=""
  rp="$(repo_path "$engine")"; fp="$(fixture_path "$engine")"

  if [[ "$engine" == duckdb ]]; then
    # No container: a fresh temporary directory holds the database file and the loader
    # logs, so every run starts from an empty database. The exported DUCKDB_DATABASE wins
    # over any config/duckdb.env, so a database you use yourself is never touched.
    # 컨테이너 없음: 새 임시 디렉터리에 데이터베이스 파일과 로더 로그를 두므로 매 실행이 빈
    # 데이터베이스에서 시작합니다. export 한 DUCKDB_DATABASE 가 config/duckdb.env 보다
    # 우선하므로 직접 쓰는 데이터베이스는 건드리지 않습니다.
    duck_dir="$(mktemp -d)"
    export DUCKDB_DATABASE="$duck_dir/tpcds.duckdb"
    load_logs="$duck_dir/load-logs"
    DUCKDB_VERSION="$(duckdb --version)"
    log "duckdb $DUCKDB_VERSION — database $DUCKDB_DATABASE"
  else
    # Always start from an empty database. Reusing a volume from a previous run makes
    # the schema step fail with "already exists" and would report a false negative.
    # 항상 빈 데이터베이스에서 시작합니다. 이전 실행의 볼륨을 재사용하면 스키마 단계가
    # "already exists" 로 실패해 거짓 음성을 보고합니다.
    log "removing any previous container and volume / 이전 컨테이너·볼륨 제거"
    "${COMPOSE[@]}" --profile "$engine" down -v >/dev/null 2>&1 || true

    log "starting container / 컨테이너 기동"
    "${COMPOSE[@]}" --profile "$engine" up -d >/dev/null 2>&1 \
      || { warn "compose up failed for $engine"; record "$engine" "container failed to start" "—" "—" "—"; return 1; }

    local limit=180
    [[ "$engine" == starrocks ]] && limit=300
    [[ "$engine" == vertica ]] && limit=300
    wait_healthy "$engine" "$limit" || { record "$engine" "unhealthy" "—" "—" "—"; return 1; }

    write_config "$engine"
  fi

  # -- schema / 스키마 ------------------------------------------------------
  local ddl_args="--engine $engine"
  needs_create_db "$engine" && ddl_args="$ddl_args --create-database"
  log "applying schema / 스키마 적용"
  if in_client "$engine" "bin/ddl.sh $ddl_args" >"/tmp/verify-$engine-ddl.log" 2>&1; then
    schema_res="✅ applied"
    ok "schema applied"
  else
    schema_res="❌ failed"
    warn "schema failed — /tmp/verify-$engine-ddl.log"
    tail -5 "/tmp/verify-$engine-ddl.log" | sed 's/^/    /'
    record "$engine" "$schema_res" "—" "—" "—"
    return 1
  fi

  # -- load / 적재 ---------------------------------------------------------
  log "loading fixture / 픽스처 적재"
  if in_client "$engine" "bin/load.sh --engine $engine --data-dir $fp --log-dir $load_logs" \
       >"/tmp/verify-$engine-load.log" 2>&1; then
    load_res="✅ 24/24 tables"
    ok "fixture loaded"
  else
    local loaded
    loaded="$(grep -c '^\[ok\].*rows' "/tmp/verify-$engine-load.log" || true)"
    load_res="⚠️ ${loaded}/24 tables"
    warn "load incomplete (${loaded}/24) — /tmp/verify-$engine-load.log"
    grep -iE '\[warn\]|\[error\]' "/tmp/verify-$engine-load.log" | head -5 | sed 's/^/    /'
  fi

  # -- queries / 쿼리 ------------------------------------------------------
  log "running all 103 queries / 103개 쿼리 실행"
  local csv="$REPO_ROOT/results/verify-$engine.csv"
  in_client "$engine" \
    "bin/run.sh --engine $engine --queries all --sf fixture --continue-on-error --out $rp/results/verify-$engine.csv" \
    >"/tmp/verify-$engine-run.log" 2>&1 || true

  if [[ -f "$csv" ]]; then
    pass="$(awk -F, 'NR>1 && $8=="ok"' "$csv" | wc -l | tr -d ' ')"
    fail="$(awk -F, 'NR>1 && $8=="error"' "$csv" | wc -l | tr -d ' ')"
    rows_total="$(awk -F, 'NR>1 && $8=="ok" {s+=$7} END {print s+0}' "$csv")"
    # Space-separated strings, not arrays: this script runs on the HOST, and macOS ships
    # bash 3.2, where mapfile/readarray do not exist and an empty array expansion trips
    # set -u. The in-container scripts can use arrays because those run on bash 5.
    # 배열이 아니라 공백 구분 문자열을 사용합니다. 이 스크립트는 호스트에서 실행되고 macOS 는
    # bash 3.2 를 제공하는데, 거기에는 mapfile/readarray 가 없고 빈 배열 전개가 set -u 를
    # 건드립니다. 컨테이너 안에서 실행되는 스크립트는 bash 5 이므로 배열을 쓸 수 있습니다.
    local failed_qs expected_qs unexpected="" now_passing="" q e hit known
    failed_qs="$(awk -F, 'NR>1 && $8=="error" {print $4}' "$csv" | sort -u | tr '\n' ' ')"
    expected_qs="$(expected_failures "$engine" | sort -u | tr '\n' ' ')"

    for q in $failed_qs; do
      hit=0
      for e in $expected_qs; do [ "$q" = "$e" ] && hit=1; done
      [ "$hit" -eq 0 ] && unexpected="$unexpected $q"
    done
    for e in $expected_qs; do
      hit=0
      for q in $failed_qs; do [ "$q" = "$e" ] && hit=1; done
      [ "$hit" -eq 0 ] && now_passing="$now_passing $e"
    done
    unexpected="$(printf '%s' "$unexpected" | tr -s ' ' | sed 's/^ //;s/ $//')"
    now_passing="$(printf '%s' "$now_passing" | tr -s ' ' | sed 's/^ //;s/ $//')"

    local n_unexpected=0
    for q in $unexpected; do n_unexpected=$((n_unexpected + 1)); done
    known=$(( fail - n_unexpected ))

    if [ "$fail" -eq 0 ]; then
      query_res="✅ $pass/103"
      ok "all $pass queries ran ($rows_total rows returned in total)"
    elif [ "$n_unexpected" -eq 0 ]; then
      query_res="✅ $pass/103 (+$known known)"
      ok "$pass queries ran; $known known failure(s), none unexpected / 알려진 실패만 발생"
      for e in $failed_qs; do
        dim "      q$e — $(expected_reason "$engine" "$e")"
      done
    else
      query_res="❌ $pass/103 ($n_unexpected unexpected)"
      warn "$n_unexpected unexpected failure(s):"
      for q in $unexpected; do printf '      q%s\n' "$q" >&2; done
    fi

    # A listed query that now passes means the list is stale — say so rather than hide it.
    # 목록의 쿼리가 이제 통과한다면 목록이 낡은 것이므로 숨기지 않고 알립니다.
    if [ -n "$now_passing" ]; then
      warn "expected-failure list is stale: q${now_passing} now passes — remove it from expected_failures()"
      warn "expected-failure 목록이 낡았습니다: q${now_passing} 가 통과합니다. expected_failures() 에서 제거하십시오"
    fi
  else
    query_res="❌ no results"
    warn "no results CSV produced — /tmp/verify-$engine-run.log"
    tail -5 "/tmp/verify-$engine-run.log" | sed 's/^/    /'
  fi

  local secs=$(( ($(now_ms) - start_ts) / 1000 ))
  record "$engine" "$schema_res" "$load_res" "$query_res" "${secs}s"

  if [[ "$engine" == duckdb ]]; then
    if [[ $KEEP -eq 0 ]]; then
      rm -rf "$duck_dir"
    else
      dim "database left at $DUCKDB_DATABASE (--keep) / 데이터베이스 유지"
    fi
  elif [[ $KEEP -eq 0 ]]; then
    log "stopping container / 컨테이너 정지"
    "${COMPOSE[@]}" --profile "$engine" down -v >/dev/null 2>&1 || true
  else
    dim "container left running (--keep) / 컨테이너 유지"
  fi

  # A partial load must not count as a pass. Queries against empty tables mostly
  # succeed, so judging on the query result alone reported "passed" for a run that
  # loaded nothing at all.
  # 부분 적재를 통과로 처리해서는 안 됩니다. 빈 테이블에 대한 쿼리는 대부분 성공하므로
  # 쿼리 결과만으로 판단하면 아무것도 적재하지 못한 실행도 "통과" 로 보고됩니다.
  [[ "$query_res" == ✅* && "$schema_res" == "✅ applied" && "$load_res" == ✅* ]]
}

record() {
  printf '| %s | %s | %s | %s | %s |\n' "$1" "$2" "$3" "$4" "$5" >> "$REPORT.rows"
}

# ---------------------------------------------------------------------------
# Fixture / 픽스처
# ---------------------------------------------------------------------------
if [[ ! -d "$FIXTURE" ]] || [[ -z "$(ls -A "$FIXTURE" 2>/dev/null)" ]]; then
  log "generating fixture → ${FIXTURE#"$REPO_ROOT"/}"
  require_cmd python3
  python3 "$REPO_ROOT/tools/make-fixture.py" --out "$FIXTURE" | tail -3
else
  dim "reusing fixture ${FIXTURE#"$REPO_ROOT"/} ($(find "$FIXTURE" -name '*.dat' | wc -l | tr -d ' ') files)"
fi
FIXTURE="$(cd "$FIXTURE" && pwd)"

mkdir -p "$REPO_ROOT/results"
rm -f "$REPORT.rows"

targets=()
if [[ $ALL -eq 1 ]]; then
  targets=("${VERIFIABLE[@]}")
else
  require_engine "$ENGINE"
  [[ "$ENGINE" == oracle ]] \
    && die "oracle cannot be verified unattended: no redistributable image / 재배포 가능한 이미지 없음
       run the steps by hand — see docs/engines/oracle.md"
  if [[ "$ENGINE" == vertica && -z "${VERTICA_IMAGE:-}" ]]; then
    die "vertica needs an image you supply: no public Vertica CE image exists since the
       OpenText acquisition. Set VERTICA_IMAGE=<image> and re-run, or follow
       docs/engines/vertica.md to run against an existing installation.
       vertica 는 직접 준비한 이미지가 필요합니다. OpenText 인수 이후 공개된 Vertica CE
       이미지가 없습니다. VERTICA_IMAGE=<image> 를 설정해 다시 실행하거나
       docs/engines/vertica.md 를 참고해 기존 설치 환경에서 실행하십시오."
  fi
  targets=("$ENGINE")
fi

# docker is needed only by the engines that run in a container.
# docker 는 컨테이너에서 실행되는 엔진에만 필요합니다.
need_docker=0
for t in "${targets[@]}"; do
  [[ "$t" == duckdb ]] && require_cmd duckdb "DuckDB CLI — install from https://duckdb.org/install/ / 설치 필요"
  [[ "$t" == duckdb ]] || need_docker=1
done
if [[ $need_docker -eq 1 ]]; then
  require_cmd docker
  docker info >/dev/null 2>&1 || die "the docker daemon is not reachable / docker 데몬에 접근할 수 없습니다"
fi

overall=0
for t in "${targets[@]}"; do
  verify_one "$t" || overall=1
done

# ---------------------------------------------------------------------------
# Report / 보고서
# ---------------------------------------------------------------------------
{
  printf '# Verification report / 검증 보고서\n\n'
  printf 'Generated by `tools/verify.sh` on %s.\n' "$(date -u +'%Y-%m-%d %H:%M UTC')"
  printf '`tools/verify.sh` 가 생성했습니다.\n\n'
  printf 'Each engine is started from `docker/docker-compose.yml` (duckdb: the host `duckdb`\n'
  printf 'CLI and a temporary database file), given the schema, loaded with the synthetic\n'
  printf 'fixture from `tools/make-fixture.py`, and then run through all 103 queries.\n\n'
  printf '각 엔진을 `docker/docker-compose.yml` 로 기동하고(duckdb 는 호스트의 `duckdb` CLI 와\n'
  printf '임시 데이터베이스 파일) 스키마를 적용한 뒤, `tools/make-fixture.py` 의 합성 픽스처를\n'
  printf '적재하고 103개 쿼리를 전부 실행합니다.\n\n'
  printf '| Engine / 엔진 | Schema / 스키마 | Load / 적재 | Queries / 쿼리 | Time / 소요 |\n'
  printf '| --- | --- | --- | --- | --- |\n'
  cat "$REPORT.rows" 2>/dev/null
  printf '\n'
  [[ -z "${DUCKDB_VERSION:-}" ]] || printf 'duckdb: host CLI %s\n\n' "$DUCKDB_VERSION"
  printf '> This proves the SQL runs. It does **not** validate answers — the official\n'
  printf '> TPC-DS answer sets are TPC EULA material and are not available here — and it\n'
  printf '> says nothing about performance.\n'
  printf '>\n'
  printf '> SQL 이 실행됨을 증명합니다. 정답 검증은 **아닙니다**(공식 TPC-DS 정답 세트는\n'
  printf '> TPC EULA 자산이라 사용할 수 없습니다). 성능에 대해서도 아무것도 말하지 않습니다.\n'
} > "$REPORT"
rm -f "$REPORT.rows"

echo
log "report → ${REPORT#"$REPO_ROOT"/}"
sed -n '/^| Engine/,/^$/p' "$REPORT"

[[ $overall -eq 0 ]] && ok "verification passed / 검증 통과" || warn "verification had failures / 검증 실패 항목 있음"
exit $overall
