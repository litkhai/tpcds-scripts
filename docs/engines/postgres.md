---
title: PostgreSQL
layout: default
parent: Engines
nav_order: 2
---

# PostgreSQL

The most thoroughly verified engine in this repository: the schema, all 103 queries
and the full `ddl` → `load` → `run` path have been executed against `postgres:16`.

이 저장소에서 가장 충실히 검증된 엔진입니다. 스키마, 103개 쿼리 전체, `ddl` → `load`
→ `run` 전체 경로를 `postgres:16` 에서 실행했습니다.

## Verified / 검증 결과

`tools/verify.sh --engine postgres` against `postgres:16`:

`postgres:16` 에 대한 `tools/verify.sh --engine postgres` 결과:

| Check / 항목 | Result / 결과 |
| --- | --- |
| Schema applies | ✅ 25 tables |
| All 103 queries plan (`EXPLAIN`) | ✅ 103/103 |
| Fixture loads | ✅ 24/24 tables |
| All 103 queries execute with data | ✅ **103/103** |
| `ddl.sh` / `load.sh` / `run.sh` end-to-end | ✅ |

Worth knowing: on an **empty** schema `query90` fails with `division by zero`, because
it computes `count(*) / count(*)` and the divisor is 0 with no rows. The query is
correct; it just needs data. That is why verification loads a fixture instead of
checking `EXPLAIN` alone.

알아둘 점: **빈** 스키마에서는 `query90` 이 `division by zero` 로 실패합니다.
`count(*) / count(*)` 를 계산하는데 행이 없으면 분모가 0 이기 때문입니다. 쿼리 자체는
정상이며 데이터만 필요합니다. 검증이 `EXPLAIN` 만 확인하지 않고 픽스처를 적재하는 이유가
바로 이것입니다.

## Setup / 설정

```bash
docker compose -f docker/docker-compose.yml --profile postgres up -d
cp config/postgres.env.example config/postgres.env

bin/ddl.sh  --engine postgres --create-database
bin/load.sh --engine postgres --data-dir ~/tpcds/sf1
bin/run.sh  --engine postgres --sf 1 --warmup 1 --iterations 3
```

## Schema / 스키마

Derived by `tools/derive-ddl.sh` from the repo's Oracle schema, which is plain TPC-DS
column text. Only one change was needed: `dv_create_time` is `date` in the Oracle
schema because Oracle has no `TIME` type, and becomes `time` here. Everything else —
`integer`, `char(N)`, `varchar(N)`, `decimal(P,S)`, `date` — is already valid
PostgreSQL.

`tools/derive-ddl.sh` 가 리포의 Oracle 스키마(표준 TPC-DS 컬럼 정의)에서 파생합니다.
필요한 변경은 하나뿐입니다. Oracle 에는 `TIME` 타입이 없어 `dv_create_time` 이
`date` 인데, 여기서는 `time` 이 됩니다. 나머지 `integer`, `char(N)`, `varchar(N)`,
`decimal(P,S)`, `date` 는 이미 유효한 PostgreSQL 입니다.

## Dialect adaptations / 방언 변환

Two changes from the standard query text, both applied by `tools/sync-upstream.sh`:

표준 쿼리 원문에서 두 가지를 변경하며, 모두 `tools/sync-upstream.sh` 가 적용합니다.

1. **Date arithmetic.** `date_add(cast('2000-08-23' as date), 30)` becomes
   `(cast('2000-08-23' as date) + 30)`. Offsets can be negative — q21 and q40 use
   `-30`, which is emitted as `- 30` rather than `+ -30`.
   **날짜 연산.** `date_add(cast('2000-08-23' as date), 30)` 이
   `(cast('2000-08-23' as date) + 30)` 이 됩니다. 오프셋은 음수일 수 있으며 q21·q40
   은 `-30` 을 사용해 `+ -30` 대신 `- 30` 으로 출력됩니다.
2. **`ORDER BY` alias in an expression.** Standard SQL lets `ORDER BY` name an output
   column only as a bare name, not inside a larger expression. q36, q70 and q86 write
   `order by ... case when lochierarchy = 0 then <col> end`, which PostgreSQL rejects
   with `column "lochierarchy" does not exist`. The alias is replaced with the
   expression it was defined as — `grouping(i_category)+grouping(i_class)` — which is
   semantically identical.
   **식 안의 `ORDER BY` 별칭.** 표준 SQL 에서 `ORDER BY` 는 출력 컬럼명을 단독으로만
   참조할 수 있고 더 큰 식 안에서는 참조할 수 없습니다. q36·q70·q86 은
   `order by ... case when lochierarchy = 0 then <col> end` 형태를 쓰는데 PostgreSQL
   이 `column "lochierarchy" does not exist` 로 거부합니다. 별칭을 정의식
   `grouping(i_category)+grouping(i_class)` 으로 치환하며 의미는 완전히 동일합니다.

## Configuration / 설정

TPC-DS is a scan-and-hash-join workload, and PostgreSQL's defaults are far too small
for it. The `docker/` profile sets:

TPC-DS 는 스캔·해시 조인 워크로드이고 PostgreSQL 기본값은 이에 크게 부족합니다.
`docker/` 프로필은 다음을 설정합니다.

```
shared_buffers=2GB          work_mem=256MB
maintenance_work_mem=1GB    effective_cache_size=6GB
max_parallel_workers_per_gather=4
max_parallel_workers=8      random_page_cost=1.1
jit=off
```

`work_mem` is the one that matters most: TPC-DS hash joins and sorts spill to disk
below roughly 128 MB, and the spill dominates the runtime. Note it is per sort or
hash node, not per query, so a parallel plan can use several multiples of it.

가장 중요한 값은 `work_mem` 입니다. TPC-DS 의 해시 조인과 정렬은 대략 128 MB 아래에서
디스크로 spill 되며, spill 이 실행 시간을 지배합니다. 쿼리당이 아니라 정렬·해시
노드당 값이므로 병렬 계획에서는 그 배수만큼 사용될 수 있습니다.

`jit=off` is deliberate: PostgreSQL's JIT frequently costs more than it saves on
TPC-DS, where compilation time is not amortised by the query's runtime.

`jit=off` 는 의도적입니다. TPC-DS 에서는 컴파일 시간이 쿼리 실행 시간으로 상환되지
않아 PostgreSQL 의 JIT 가 얻는 것보다 비용이 큰 경우가 많습니다.

## Loading / 적재

`COPY ... FROM STDIN WITH (FORMAT csv, DELIMITER '|', NULL '')`.

dsdgen ends every line with a trailing `|`, which `COPY` would read as an extra empty
column. `load.sh` strips it with `sed 's/|$//'` on the way in rather than rewriting
the generated files.

dsdgen 은 각 줄 끝에 `|` 를 붙이며 `COPY` 는 이를 추가 빈 컬럼으로 인식합니다.
`load.sh` 는 생성 파일을 수정하지 않고 적재 중에 `sed 's/|$//'` 로 제거합니다.

`load.sh` runs `ANALYZE` at the end. This is not optional — without statistics the
planner picks nested loops for the large fact joins and several queries become
unusable.

`load.sh` 는 마지막에 `ANALYZE` 를 실행합니다. 선택이 아닙니다. 통계가 없으면
플래너가 대형 팩트 조인에 중첩 루프를 선택해 일부 쿼리를 사용할 수 없게 됩니다.
