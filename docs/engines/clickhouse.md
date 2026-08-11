# ClickHouse

Schema and queries are imported **verbatim** from
[`ClickHouse/ClickHouse`](https://github.com/ClickHouse/ClickHouse)
`tests/benchmarks/tpc-ds/` (Apache-2.0), at the commit pinned in
`tools/sync-upstream.sh`. Nothing was rewritten.

스키마와 쿼리는 [`ClickHouse/ClickHouse`](https://github.com/ClickHouse/ClickHouse)
`tests/benchmarks/tpc-ds/` (Apache-2.0) 에서 `tools/sync-upstream.sh` 에 핀 고정된
커밋으로 **그대로** 가져왔습니다. 재작성한 부분은 없습니다.

## Verified / 검증 결과

`tools/verify.sh --engine clickhouse` against ClickHouse 26.7: schema applies,
24/24 tables load, **102/103 queries run** — the one failure is expected and the run passes.

ClickHouse 26.7 에 대한 `tools/verify.sh --engine clickhouse` 결과: 스키마 적용,
24/24 테이블 적재, **103개 중 102개 쿼리 실행**. 남은 1건은 예상된 실패이며 검증은 통과합니다.

| Query | Cause / 원인 |
| --- | --- |
| q61 | Divides by a `count(*)` the small verification fixture leaves at 0 — a fixture-size artifact, not a defect. Registered in `expected_failures()` in `tools/verify.sh`, so a run whose only failure is this one still passes, while any new failure turns the run red. / 검증용 소규모 픽스처에서 0 이 되는 `count(*)` 로 나눕니다. 결함이 아니라 픽스처 크기에서 오는 현상입니다. `tools/verify.sh` 의 `expected_failures()` 에 등록되어 이 실패만 있으면 통과하고, 새로운 실패가 생기면 실패로 바뀝니다. |
| ~~q30, q81~~ | **Fixed upstream.** On ClickHouse 25.11 these failed because the engine could not resolve an outer CTE alias referenced inside a subquery over a second instance of the same CTE — `WHERE ctr1.ctr_state = ctr2.ctr_state` over `customer_total_return` — with `enable_analyzer` either on or off. They pass on 26.7. CI caught the difference by pulling a newer image than the local run had, which is a good argument for not pinning `latest` in the compose profile. / **상류에서 수정됨.** ClickHouse 25.11 에서는 `enable_analyzer` 를 켜도 꺼도 실패했지만 26.7 에서는 통과합니다. CI 가 로컬보다 새 이미지를 받아 차이를 발견했습니다. |

!!! warning "Warning / 주의"

    The settings in `config/clickhouse.env.example` are **required**, not tuning. Three
    of them stop queries failing outright, and three change results silently. See below.

    `config/clickhouse.env.example` 의 설정은 튜닝이 아니라 **필수**입니다. 세 개는 쿼리
    실패를 막고, 세 개는 결과를 조용히 바꿉니다. 아래를 참고하십시오.


## Required settings / 필수 설정

The upstream benchmark directory ships a `settings.json`, preserved here as
`engines/clickhouse/reference/upstream-settings.json`. Those settings are wired into
`config/clickhouse.env.example` as `CH_EXTRA_ARGS` because the query set does not work
without them:

상류 벤치마크 디렉터리는 `settings.json` 을 제공하며 여기에
`engines/clickhouse/reference/upstream-settings.json` 으로 보존했습니다. 쿼리 세트가 이
설정 없이는 동작하지 않으므로 `config/clickhouse.env.example` 의 `CH_EXTRA_ARGS` 로
연결해 두었습니다.

| Setting | Without it / 없으면 |
| --- | --- |
| `union_default_mode=DISTINCT` | q49, q75 fail: "Expected ALL or DISTINCT in SelectWithUnion query" |
| `joined_subquery_requires_alias=0` | q14_1, q14_2 fail: "no alias for subquery or table function" |
| `intersect_default_mode=DISTINCT` | the `INTERSECT` in q14 needs an explicit mode |
| `join_use_nulls=1` | outer joins yield type defaults instead of NULL — **wrong answers, no error** |
| `group_by_use_nulls=1` | `ROLLUP` / `GROUPING()` yield type defaults — **wrong answers, no error** |
| `data_type_default_nullable=1` | columns are non-Nullable, changing NULL semantics throughout |

The last three are the dangerous ones: they do not fail, they quietly change results.
Verified: applying them took the run from 96/103 to 102/103.

마지막 세 개가 위험합니다. 실패하지 않고 결과를 조용히 바꿉니다. 이 설정을 적용해
96/103 에서 102/103 으로 개선되는 것을 확인했습니다.

## Setup / 설정

```bash
docker compose -f docker/docker-compose.yml --profile clickhouse up -d
cp config/clickhouse.env.example config/clickhouse.env

bin/ddl.sh  --engine clickhouse --create-database
bin/load.sh --engine clickhouse --data-dir ~/tpcds/sf1
bin/run.sh  --engine clickhouse --sf 1 --warmup 1 --iterations 3
```

For ClickHouse Cloud, set `CH_EXTRA_ARGS='--secure'` and use port 9440.

ClickHouse Cloud 는 `CH_EXTRA_ARGS='--secure'` 를 설정하고 포트 9440 을 사용합니다.

## Schema / 스키마

The upstream schema maps TPC-DS types as: `identifier` → `Int64` (except `*_date_sk`
and `*_time_sk` → `UInt32`), `integer` → `Int64`, `decimal(P,S)` → `Decimal(P,S)`,
`char(N)` → `FixedString(N)`, `varchar(N)` → `String`, `date` → `Date`.

상류 스키마는 TPC-DS 타입을 다음과 같이 매핑합니다. `identifier` → `Int64`
(`*_date_sk`, `*_time_sk` 는 `UInt32`), `integer` → `Int64`, `decimal(P,S)` →
`Decimal(P,S)`, `char(N)` → `FixedString(N)`, `varchar(N)` → `String`, `date` →
`Date`.

!!! note "Note / 참고"

    The tables declare `PRIMARY KEY (...)` with **no explicit `ENGINE` clause**. This is
    valid: ClickHouse falls back to `default_table_engine`, which is `MergeTree`, and a
    `PRIMARY KEY` implies the `ORDER BY`. If you run an older ClickHouse where
    `default_table_engine` is unset, add `ENGINE = MergeTree` explicitly.

    테이블은 **명시적 `ENGINE` 절 없이** `PRIMARY KEY (...)` 를 선언합니다. 유효한
    방식입니다. ClickHouse 가 `default_table_engine`(기본 `MergeTree`)로 대체하고
    `PRIMARY KEY` 가 `ORDER BY` 를 함의합니다. `default_table_engine` 이 설정되지 않은
    구버전에서는 `ENGINE = MergeTree` 를 명시적으로 추가하십시오.


There is no separate statistics step — ClickHouse does not use table statistics the
way a cost-based optimiser does, so `engines/clickhouse/tuning/` holds no SQL.

별도의 통계 단계가 없습니다. ClickHouse 는 비용 기반 옵티마이저처럼 테이블 통계를
사용하지 않으므로 `engines/clickhouse/tuning/` 에는 SQL 이 없습니다.

## Known upstream issues / 알려진 상류 이슈

The upstream benchmark directory ships a list of queries that do not work
out-of-the-box, preserved here as
`engines/clickhouse/reference/upstream-known-issues.md`. Read it before treating a
failure as a bug in this repository. At the pinned commit it covers:

상류 벤치마크 디렉터리는 그대로 실행되지 않는 쿼리 목록을 제공하며, 여기에
`engines/clickhouse/reference/upstream-known-issues.md` 로 보존했습니다. 실패를 이
저장소의 버그로 판단하기 전에 확인하십시오. 핀 고정 커밋 기준 내용:

| Query | Issue / 이슈 |
| --- | --- |
| q17 | `stddev_samp` over a single value returns `nan` instead of `NULL`. Otherwise correct. / 단일 값에 대한 `stddev_samp` 가 `NULL` 대신 `nan` 반환. 그 외는 정상. |
| q35 | Memory limit exceeded with a reasonable memory allowance. / 합리적인 메모리 한계에서도 초과. |
| q47, q57, q58, q75 | Do not run as written; the upstream note gives a working alternative formulation for each. / 원문 그대로는 실행되지 않으며, 상류 노트가 각각 동작하는 대체 정식화를 제공. |

The upstream file also carries `engines/clickhouse/reference/upstream-settings.json`,
the settings the ClickHouse project uses for its own runs.

상류 파일에는 ClickHouse 프로젝트가 자체 실행에 사용하는 설정인
`engines/clickhouse/reference/upstream-settings.json` 도 포함되어 있습니다.

## Loading / 적재

`INSERT INTO <table> FORMAT CSV` with `--format_csv_delimiter='|'`, plus:

`--format_csv_delimiter='|'` 와 함께 다음을 사용합니다.

- `--input_format_null_as_default=1` — an empty field becomes the column default,
  which is what dsdgen means by an empty field in a non-`Nullable` column.
  빈 필드를 컬럼 기본값으로 처리합니다. dsdgen 이 non-`Nullable` 컬럼에서 빈 필드로
  표현하는 의미와 일치합니다.
- `--date_time_input_format=best_effort` — accepts the date formats dsdgen emits.
  dsdgen 이 출력하는 날짜 형식을 허용합니다.
- The trailing `|` on every line is stripped on the way in.
  각 줄 끝의 `|` 를 적재 중에 제거합니다.

After loading, `load.sh` runs `OPTIMIZE TABLE ... FINAL` on each table so the first
query run is not competing with background merges for I/O. On a large scale factor
this takes a while; set `CH_OPTIMIZE_AFTER_LOAD=0` to skip it.

적재 후 `load.sh` 가 각 테이블에 `OPTIMIZE TABLE ... FINAL` 을 실행해 첫 쿼리 실행이
백그라운드 머지와 I/O 를 경합하지 않도록 합니다. 큰 스케일 팩터에서는 시간이 걸리므로
생략하려면 `CH_OPTIMIZE_AFTER_LOAD=0` 을 설정하십시오.

The Docker profile raises `nofile` to 262144. The default in some Docker setups is low
enough to break merges on the large fact tables.

Docker 프로필은 `nofile` 을 262144 로 올립니다. 일부 Docker 환경의 기본값은 대형 팩트
테이블 머지를 실패시킬 만큼 낮습니다.
