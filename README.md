# tpcds-scripts

**TPC-DS derived schemas, queries and runner scripts for Oracle, PostgreSQL, Vertica, ClickHouse and StarRocks.**

**Oracle, PostgreSQL, Vertica, ClickHouse, StarRocks 를 위한 TPC-DS 파생 스키마·쿼리·실행 스크립트.**

> ⚠️ Results measured with these scripts are **not** TPC-DS results and are **not**
> comparable to published TPC-DS results. See [`NOTICE.md`](NOTICE.md).
>
> ⚠️ 이 스크립트로 측정한 값은 TPC-DS 결과가 **아니며** 공표된 TPC-DS 결과와 비교할 수
> **없습니다**. [`NOTICE.md`](NOTICE.md) 참고.

---

## What this is / 개요

A single place to stand up the TPC-DS workload on five different databases and run
it the same way on each. For every engine the repository carries the schema, the
full 103-query set in that engine's dialect, a bulk loader that speaks that engine's
native tool, and tuning scripts — driven by one common set of commands.

다섯 개의 서로 다른 데이터베이스에 TPC-DS 워크로드를 구성하고 동일한 방식으로
실행하기 위한 저장소입니다. 각 엔진에 대해 스키마, 해당 엔진 방언의 103개 쿼리 전체
세트, 엔진 고유 도구를 사용하는 벌크 로더, 튜닝 스크립트를 제공하며, 공통 명령
세트로 구동합니다.

Two things this repository takes seriously:

이 저장소가 특히 중요하게 다루는 두 가지:

1. **Provenance.** Every SQL file states which upstream repository it came from, at
   which commit, under which licence, and exactly what was changed. Nothing is
   copy-pasted without attribution.
   **출처.** 모든 SQL 파일에 상류 리포지토리, 커밋, 라이선스, 변경 내용이 명시되어
   있습니다. 출처 없이 복사해 온 것은 없습니다.
2. **Licensing.** The TPC-DS toolkit is TPC EULA material, not open source. It is
   never vendored here — you fetch it yourself, and it lands in a git-ignored
   directory.
   **라이선스.** TPC-DS 툴킷은 오픈소스가 아닌 TPC EULA 자산입니다. 이 저장소에
   포함하지 않으며, 직접 받은 결과물은 git 에서 제외되는 디렉터리에 저장됩니다.

## History / 연혁

This repository began as a set of Oracle-only TPC-DS scripts: a single
`tpcds_oracle_ddl.sql`, SQL*Loader control files, and 99 queries rewritten in Oracle
dialect. That work is preserved — the Oracle assets are repo-native and were carried
into the new layout with `git mv`, so their history is intact — and the repository
was then restructured around a per-engine layout with four more engines added.

이 저장소는 Oracle 전용 TPC-DS 스크립트로 시작했습니다. 단일
`tpcds_oracle_ddl.sql`, SQL*Loader 컨트롤 파일, Oracle 방언으로 재작성한 99개 쿼리가
그것입니다. 해당 작업은 그대로 보존되어 있으며(Oracle 자산은 리포 고유 자산으로
`git mv` 로 새 구조에 이동해 이력이 유지됩니다), 이후 엔진별 구조로 재구성하고 네 개
엔진을 추가했습니다.

## Engine support / 엔진 지원 현황

| Engine / 엔진 | Schema | Queries | Loader / 로더 | Tuning / 튜닝 | Docker |
| --- | :-: | :-: | --- | --- | :-: |
| Oracle | ✅ | 103 | SQL\*Loader (`sqlldr`) | indexes, `DBMS_STATS` | ✖ ([why / 이유](docs/engines/oracle.md)) |
| PostgreSQL | ✅ | 103 | `COPY` | indexes, `ANALYZE` | ✅ |
| Vertica | ✅ | 103 | `COPY ... DIRECT` | Database Designer guidance | ✅ (CE) |
| ClickHouse | ✅ | 103 | `INSERT ... FORMAT CSV` | schema `ORDER BY` keys | ✅ |
| StarRocks | ✅ | 103 | Stream Load | `ANALYZE`, bucketing notes | ✅ |

103 = the 99 TPC-DS queries, where 14, 23, 24 and 39 each have two formulations.

103 = TPC-DS 99개 쿼리 기준, 14·23·24·39 는 각각 두 가지 정식화를 가집니다.

## Verification status / 검증 현황

Reported honestly, because "it's in the repo" is not the same as "it runs":

"저장소에 있다"와 "실행된다"는 다르므로 사실대로 기재합니다.

| Check / 검증 항목 | Result / 결과 |
| --- | --- |
| PostgreSQL schema applies (25 tables) | ✅ verified against `postgres:16` |
| PostgreSQL — all 103 queries plan (`EXPLAIN`) | ✅ 103/103 |
| PostgreSQL — all 103 queries execute on an empty schema | ✅ 102/103. q90 divides by `count(*)`, which is 0 with no data; it needs a loaded database, and the query itself is correct. / q90 은 `count(*)` 로 나누므로 데이터가 없으면 0 이 됩니다. 적재된 DB 가 필요하며 쿼리 자체는 정상입니다. |
| `bin/ddl.sh`, `bin/load.sh`, `bin/run.sh` end-to-end | ✅ verified against PostgreSQL with fixture data |
| All shell scripts parse (`bash -n`) | ✅ |
| `docker/docker-compose.yml` valid | ✅ |
| Oracle, Vertica, ClickHouse, StarRocks execution | ⬜ **not yet run.** Schemas and queries are imported verbatim from upstream test suites or derived from the same base, but no run has been executed against these engines in this repository. / ⬜ **미실행.** 스키마·쿼리는 상류 테스트 스위트에서 그대로 가져왔거나 동일 베이스에서 파생했지만, 이 저장소에서 해당 엔진에 대해 실행한 적은 없습니다. |

## Quick start / 빠른 시작

```bash
# 1. Start an engine / 엔진 기동 (PostgreSQL example)
docker compose -f docker/docker-compose.yml --profile postgres up -d

# 2. Connection settings / 접속 설정
cp config/postgres.env.example config/postgres.env

# 3. Get the TPC-DS toolkit and generate data / 툴킷 확보 및 데이터 생성
#    Prompts you to accept the TPC EULA. / TPC EULA 동의를 요구합니다.
datagen/fetch-toolkit.sh --community
datagen/generate.sh --sf 1 --out ~/tpcds/sf1

# 4. Schema and load / 스키마 생성 및 적재
bin/ddl.sh  --engine postgres
bin/load.sh --engine postgres --data-dir ~/tpcds/sf1

# 5. Run / 실행
bin/run.sh  --engine postgres --sf 1 --iterations 3
```

Results land in `results/<timestamp>-<engine>-sf<n>.csv`.

결과는 `results/<timestamp>-<engine>-sf<n>.csv` 에 저장됩니다.

Swap `postgres` for `oracle`, `vertica`, `clickhouse` or `starrocks` — the commands
are identical. Per-engine setup notes are in [`docs/engines/`](docs/engines/).

`postgres` 를 `oracle`, `vertica`, `clickhouse`, `starrocks` 로 바꾸면 되며 명령은
동일합니다. 엔진별 설정 안내는 [`docs/engines/`](docs/engines/) 에 있습니다.

## Repository layout / 저장소 구조

```
tpcds-scripts/
├── bin/                        Common commands / 공통 명령
│   ├── ddl.sh                    create schema, optionally tuning / 스키마·튜닝 생성
│   ├── load.sh                   dispatch to the engine's bulk loader / 엔진 로더 위임
│   ├── run.sh                    execute queries, record timings / 쿼리 실행·시간 기록
│   └── lib/common.sh             engine dispatch, config, query selection
├── engines/
│   ├── oracle/                 Repo-native / 리포 고유 자산
│   │   ├── ddl/schema.sql        25 tables / 테이블
│   │   ├── load/ctl/*.ctl        24 SQL*Loader templates, named by table
│   │   ├── load/load.sh          renders @DATA_DIR@ / @LOG_DIR@, runs sqlldr
│   │   ├── queries/*.sql         103 queries, Oracle dialect
│   │   └── tuning/               indexes.sql, stats.sql
│   ├── postgres/  vertica/       derived from the standard query text
│   └── clickhouse/  starrocks/   imported verbatim from upstream (Apache-2.0)
├── datagen/
│   ├── fetch-toolkit.sh        obtain + build dsdgen (never vendored / 미포함)
│   └── generate.sh             produce .dat files at a scale factor
├── docker/docker-compose.yml   local engines, one profile each
├── config/*.env.example        connection settings templates
├── tools/
│   ├── sync-upstream.sh        re-import upstream at pinned commits
│   └── derive-ddl.sh           generate Postgres/Vertica schemas
├── docs/                       GitHub Pages site / GitHub Pages 사이트
├── results/                    run output (git-ignored / git 제외)
├── LICENSE                     Apache-2.0, for this repository's own code
└── NOTICE.md                   provenance and TPC licensing / 출처 및 TPC 라이선스
```

## How the query sets were built / 쿼리 세트 구성 방법

| Engine | Source / 출처 | Change / 변경 |
| --- | --- | --- |
| Oracle | Repo-native, pre-existing | Oracle dialect: `rownum <= 100`, `to_date(...) + N` |
| ClickHouse | `ClickHouse/ClickHouse` `tests/benchmarks/tpc-ds/` (Apache-2.0) | Verbatim; q14/23/24/39 split into `_1`/`_2` |
| StarRocks | `StarRocks/starrocks` `.../sql/tpcds/` (Apache-2.0) | Verbatim |
| PostgreSQL, Vertica | Derived from the StarRocks copy of the standard query text | `date_add(d, n)` → `(d ± n)`; `ORDER BY` alias expanded in q36/q70/q86 |

Re-run [`tools/sync-upstream.sh`](tools/sync-upstream.sh) to reproduce all of it
from the pinned commits. Full detail, including why some sources were rejected, is
in [`NOTICE.md`](NOTICE.md).

[`tools/sync-upstream.sh`](tools/sync-upstream.sh) 를 다시 실행하면 핀 고정 커밋에서
전체를 재생성할 수 있습니다. 일부 소스를 배제한 이유를 포함한 상세 내용은
[`NOTICE.md`](NOTICE.md) 에 있습니다.

## Licensing in one paragraph / 라이선스 요약

The scripts in this repository are Apache-2.0 ([`LICENSE`](LICENSE)). The TPC-DS
schema and query text are derived from a TPC benchmark specification and remain
subject to TPC's rights; the data generator is TPC EULA material and is not included
here. Anything you measure is "TPC-DS derived" and must not be presented as a
TPC-DS result. Read [`NOTICE.md`](NOTICE.md) before publishing numbers.

이 저장소의 스크립트는 Apache-2.0 ([`LICENSE`](LICENSE)) 입니다. TPC-DS 스키마와 쿼리
원문은 TPC 벤치마크 규격에서 파생된 것으로 TPC 의 권리가 유지됩니다. 데이터 생성기는
TPC EULA 자산이며 여기에 포함되지 않습니다. 측정한 값은 "TPC-DS 파생" 이며 TPC-DS
결과로 제시해서는 안 됩니다. 수치를 공개하기 전에 [`NOTICE.md`](NOTICE.md) 를
읽어보십시오.

## Documentation / 문서

- [Methodology and fair use / 측정 방법론 및 fair use](docs/methodology.md)
- [Oracle](docs/engines/oracle.md) · [PostgreSQL](docs/engines/postgres.md) ·
  [Vertica](docs/engines/vertica.md) · [ClickHouse](docs/engines/clickhouse.md) ·
  [StarRocks](docs/engines/starrocks.md)
- [Contributing / 기여 안내](CONTRIBUTING.md)

## Contributing / 기여

Adding an engine, correcting a dialect adaptation, or reporting a query that fails
on a real dataset are all welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md) —
in particular, do not edit imported query files by hand; change
`tools/sync-upstream.sh` so the adaptation stays reproducible and documented.

엔진 추가, 방언 변환 수정, 실제 데이터셋에서 실패하는 쿼리 제보 모두 환영합니다.
[`CONTRIBUTING.md`](CONTRIBUTING.md) 를 참고하십시오. 특히 임포트된 쿼리 파일을 직접
수정하지 말고 `tools/sync-upstream.sh` 를 수정해 변환이 재현·문서화되도록 유지하십시오.
