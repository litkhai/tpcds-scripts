# Contributing / 기여 안내

## The one rule that matters most / 가장 중요한 한 가지 규칙

**Do not hand-edit files under `engines/*/queries/` or `engines/*/ddl/`.**

**`engines/*/queries/` 와 `engines/*/ddl/` 아래 파일을 직접 수정하지 마십시오.**

Those files are generated. Each carries a header naming its upstream source, commit
and the adaptation applied, and `tools/sync-upstream.sh` regenerates all of them.
A hand-edit makes the header a lie and disappears the next time anyone re-syncs.

해당 파일들은 생성물입니다. 각 파일 헤더에 상류 출처·커밋·적용된 변환이 기재되어
있고, `tools/sync-upstream.sh` 가 전체를 재생성합니다. 직접 수정하면 헤더가 사실과
달라지고, 다음 재동기화 때 변경이 사라집니다.

Instead:

대신 다음과 같이 하십시오.

| To change / 변경 대상 | Edit / 수정할 파일 |
| --- | --- |
| A dialect adaptation for Postgres or Vertica | `to_ansi()` in `tools/sync-upstream.sh` |
| Which upstream commit is used | the `*_REF` constants at the top of `tools/sync-upstream.sh` |
| The Postgres / Vertica schema | `tools/derive-ddl.sh` |
| The Oracle schema, queries or `.ctl` files | edit directly — these are repo-native / 리포 고유 자산이므로 직접 수정 |

Then re-run and commit the result:

이후 재실행하고 결과를 커밋하십시오.

```bash
tools/sync-upstream.sh all
tools/derive-ddl.sh all
git diff --stat        # review what changed / 변경 내용 확인
```

## Adding an engine / 엔진 추가

1. `engines/<name>/ddl/schema.sql` — the schema. Import from an appropriately
   licensed upstream, or derive it in `tools/derive-ddl.sh`. Record the source.
   스키마. 적절한 라이선스의 상류에서 임포트하거나 `tools/derive-ddl.sh` 에서
   파생하십시오. 출처를 기록하십시오.
2. `engines/<name>/queries/` — 103 files named `query01.sql` … `query99.sql`, with
   `query14_1.sql` / `query14_2.sql` for the four queries that have two formulations.
   `query01.sql` … `query99.sql` 형식의 103개 파일. 두 가지 정식화를 가진 네 개
   쿼리는 `query14_1.sql` / `query14_2.sql` 형식.
3. `engines/<name>/load/load.sh` — reads `DATA_DIR`, `LOG_DIR` and
   `TPCDS_LOAD_TABLES` from the environment; must exit non-zero on failure.
   환경변수 `DATA_DIR`, `LOG_DIR`, `TPCDS_LOAD_TABLES` 를 읽고, 실패 시 non-zero 로
   종료해야 합니다.
4. `bin/lib/common.sh` — add the engine to `ENGINES`, and add cases to
   `engine_exec`, `engine_exec_nodb` and `check_client`.
   `ENGINES` 에 엔진을 추가하고 `engine_exec`, `engine_exec_nodb`, `check_client` 에
   케이스를 추가하십시오.
5. `config/<name>.env.example` — connection variables. / 접속 변수.
6. `docker/docker-compose.yml` — a profile, if a redistributable image exists.
   재배포 가능한 이미지가 있으면 프로필을 추가하십시오.
7. `docs/engines/<name>.md` and the tables in `README.md` and `NOTICE.md`.
   `docs/engines/<name>.md` 및 `README.md`·`NOTICE.md` 의 표를 갱신하십시오.

### `engine_exec` contract / `engine_exec` 계약

Reads SQL on stdin, writes result rows to stdout, **exits non-zero when the engine
reports an error.** Getting the last part wrong is the failure mode to watch for: a
client that swallows errors turns a broken query into a suspiciously fast success in
the results CSV.

stdin 으로 SQL 을 받아 stdout 으로 결과 행을 출력하고, **엔진이 오류를 보고하면
non-zero 로 종료해야 합니다.** 마지막 항목이 가장 흔한 실패 지점입니다. 오류를 삼키는
클라이언트는 깨진 쿼리를 결과 CSV 에서 의심스럽게 빠른 성공으로 기록하게 만듭니다.

## Licensing requirements for contributions / 기여 시 라이선스 요건

Before importing SQL from anywhere, check the actual `LICENSE` file in that
repository — not the language on its README, and not the fact that other projects
already copied it.

어디서든 SQL 을 가져오기 전에 해당 리포지토리의 실제 `LICENSE` 파일을 확인하십시오.
README 의 문구나 "다른 프로젝트가 이미 복사했다"는 사실로는 충분하지 않습니다.

```bash
curl -s https://api.github.com/repos/<owner>/<repo>/license \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['license']['spdx_id'], d['path'])"
```

- **Acceptable / 허용:** Apache-2.0, MIT, BSD, and similar permissive licences, with
  attribution recorded in the file header and in `NOTICE.md`.
  Apache-2.0, MIT, BSD 등 허용적 라이선스. 파일 헤더와 `NOTICE.md` 에 출처 기록.
- **Not acceptable / 불허:** anything under the TPC EULA, `NOASSERTION`, or no
  licence at all. This includes the TPC-DS toolkit, the official query templates and
  the official answer sets.
  TPC EULA 대상, `NOASSERTION`, 라이선스 없음. TPC-DS 툴킷, 공식 쿼리 템플릿, 공식
  정답 세트가 여기 해당합니다.

Never commit anything into `.toolkit/`. It is git-ignored for a reason.

`.toolkit/` 에 어떤 것도 커밋하지 마십시오. git 에서 제외한 이유가 있습니다.

## Before opening a pull request / PR 전 확인

```bash
# Scripts parse / 스크립트 파싱
find . -name '*.sh' -not -path './.git/*' -exec bash -n {} \;

# Compose file valid / compose 파일 검증
docker compose -f docker/docker-compose.yml config >/dev/null

# Generated files are in sync with the tools that produce them
# 생성 파일이 생성 도구와 동기화되어 있는지 확인
tools/sync-upstream.sh all && tools/derive-ddl.sh all && git diff --exit-code
```

If you changed queries for an engine you can run, say so in the PR and give the
counts. If you could not run it, say that too — an untested import is fine as long
as it is labelled. `README.md` has a verification table that should stay accurate.

실행 가능한 엔진의 쿼리를 변경했다면 PR 에 실행 결과와 건수를 적어주십시오. 실행하지
못했다면 그 사실도 적어주십시오. 표시만 되어 있다면 미검증 임포트도 괜찮습니다.
`README.md` 의 검증 표는 항상 정확하게 유지해야 합니다.

## Reporting a failing query / 실패 쿼리 제보

Include the engine and version, the scale factor, the query number, and the engine's
error text. If it fails only with data loaded — like `query90`, which divides by a
count that is zero on an empty schema — say so; that distinction usually points
straight at the cause.

엔진과 버전, 스케일 팩터, 쿼리 번호, 엔진 오류 메시지를 포함해 주십시오. 데이터가
적재된 상태에서만 실패한다면(빈 스키마에서 0 이 되는 count 로 나누는 `query90` 처럼)
그 사실을 명시해 주십시오. 이 구분만으로 원인이 드러나는 경우가 많습니다.
