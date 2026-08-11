---
title: Home
layout: default
nav_order: 1
---

# tpcds-scripts

**TPC-DS derived schemas, queries and runner scripts for Oracle, PostgreSQL, Vertica, ClickHouse and StarRocks.**

**Oracle, PostgreSQL, Vertica, ClickHouse, StarRocks 를 위한 TPC-DS 파생 스키마·쿼리·실행 스크립트.**

{: .warning }
> Results measured with these scripts are **not** TPC-DS results and are **not**
> comparable to published TPC-DS results.
> See [Methodology and fair use](methodology.md).
>
> 이 스크립트로 측정한 값은 TPC-DS 결과가 **아니며** 공표된 TPC-DS 결과와 비교할 수
> **없습니다**. [측정 방법론 및 fair use](methodology.md) 참고.

---

## What this is / 개요

One place to stand up the TPC-DS workload on five databases and run it the same way
on each. For every engine: the schema, the full 103-query set in that engine's
dialect, a loader using that engine's native bulk tool, and tuning scripts — all
driven by one common set of commands.

다섯 개 데이터베이스에 TPC-DS 워크로드를 구성하고 동일한 방식으로 실행하기 위한
저장소입니다. 각 엔진에 대해 스키마, 해당 엔진 방언의 103개 쿼리 전체 세트, 엔진 고유
벌크 도구를 사용하는 로더, 튜닝 스크립트를 제공하며 공통 명령 세트로 구동합니다.

## Engine support / 엔진 지원 현황

| Engine / 엔진 | Queries | Loader / 로더 | Docker | Guide / 안내 |
| --- | :-: | --- | :-: | --- |
| Oracle | 103 | SQL\*Loader | ✖ | [oracle](engines/oracle.md) |
| PostgreSQL | 103 | `COPY` | ✅ | [postgres](engines/postgres.md) |
| Vertica | 103 | `COPY ... DIRECT` | ✖ BYO image | [vertica](engines/vertica.md) |
| ClickHouse | 103 | `INSERT ... FORMAT CSV` | ✅ | [clickhouse](engines/clickhouse.md) |
| StarRocks | 103 | Stream Load | ✅ | [starrocks](engines/starrocks.md) |

103 = the 99 TPC-DS queries, where 14, 23, 24 and 39 each have two formulations.

103 = TPC-DS 99개 쿼리 기준, 14·23·24·39 는 각각 두 가지 정식화를 가집니다.

## Quick start / 빠른 시작

```bash
# 1. Start an engine / 엔진 기동
docker compose -f docker/docker-compose.yml --profile postgres up -d

# 2. Connection settings / 접속 설정
cp config/postgres.env.example config/postgres.env

# 3. Toolkit and data / 툴킷 및 데이터
datagen/fetch-toolkit.sh --community
datagen/generate.sh --sf 1 --out ~/tpcds/sf1

# 4. Schema and load / 스키마 생성 및 적재
bin/ddl.sh  --engine postgres
bin/load.sh --engine postgres --data-dir ~/tpcds/sf1

# 5. Run / 실행
bin/run.sh  --engine postgres --sf 1 --iterations 3
```

## The commands / 명령

### `bin/ddl.sh`

```
--engine <name>      required / 필수
--create-database    CREATE DATABASE first (postgres, clickhouse, starrocks)
--tuning             also apply engines/<engine>/tuning/*.sql
--drop               DROP the 24 TPC-DS tables, then stop
```

### `bin/load.sh`

```
--engine <name>      required / 필수
--data-dir <dir>     directory of dsdgen .dat files / .dat 파일 디렉터리 (required)
--log-dir <dir>      loader logs and rejected rows / 로더 로그·거부 행
--tables <spec>      all (default) | comma-separated names
```

Tables load dimensions before facts, so a run with enforced referential integrity
also succeeds.

차원 테이블을 팩트보다 먼저 적재하므로 참조 정합성을 강제한 경우에도 성공합니다.

### `bin/run.sh`

```
--engine <name>      required / 필수
--queries <spec>     all (default) | 1,5,22 | 1-10 | 14_2
--iterations <n>     measured runs per query / 쿼리별 측정 횟수
--warmup <n>         unmeasured runs first / 측정 전 예열 횟수
--sf <n>             scale factor, recorded in the CSV / CSV 에 기록되는 스케일 팩터
--out <file>         results CSV path / 결과 CSV 경로
--keep-output        keep result rows / 결과 행 보관
--continue-on-error  do not stop at the first failure / 실패해도 계속
```

Output CSV columns: `run_stamp, engine, scale_factor, query, iteration, elapsed_ms,
rows, status`.

## Licensing / 라이선스

The scripts here are Apache-2.0. The TPC-DS schema and query text derive from a TPC
benchmark specification and remain subject to TPC's rights; the data generator is
TPC EULA material and is not included in the repository. Full detail, including
per-file provenance and the sources that were deliberately rejected, is in
[`NOTICE.md`](https://github.com/litkhai/tpcds-scripts/blob/master/NOTICE.md).

여기의 스크립트는 Apache-2.0 입니다. TPC-DS 스키마와 쿼리 원문은 TPC 벤치마크 규격에서
파생되어 TPC 의 권리가 유지되며, 데이터 생성기는 TPC EULA 자산으로 저장소에 포함되지
않습니다. 파일별 출처와 의도적으로 배제한 소스를 포함한 상세 내용은
[`NOTICE.md`](https://github.com/litkhai/tpcds-scripts/blob/master/NOTICE.md) 에
있습니다.
