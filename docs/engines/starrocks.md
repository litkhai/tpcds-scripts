---
title: StarRocks
layout: default
parent: Engines
nav_order: 5
---

# StarRocks

Schema and queries are imported **verbatim** from
[`StarRocks/starrocks`](https://github.com/StarRocks/starrocks)
`fe/fe-core/src/test/resources/sql/tpcds/` (Apache-2.0), at the commit pinned in
`tools/sync-upstream.sh`.

스키마와 쿼리는 [`StarRocks/starrocks`](https://github.com/StarRocks/starrocks)
`fe/fe-core/src/test/resources/sql/tpcds/` (Apache-2.0) 에서
`tools/sync-upstream.sh` 에 핀 고정된 커밋으로 **그대로** 가져왔습니다.

This set is also the base for the PostgreSQL and Vertica query sets, because it
carries the plain TPC-DS qualification query text with the standard substitution
parameters.

이 세트는 표준 치환 파라미터를 가진 TPC-DS qualification 쿼리 원문을 담고 있어
PostgreSQL 과 Vertica 쿼리 세트의 베이스이기도 합니다.

## Verified / 검증 결과

`tools/verify.sh --engine starrocks` against the `starrocks/allin1-ubuntu` image:
schema applies, 24/24 tables load, **103/103 queries run**.

`starrocks/allin1-ubuntu` 이미지에 대한 `tools/verify.sh --engine starrocks` 결과:
스키마 적용, 24/24 테이블 적재, **103개 중 103개 쿼리 실행**.

Getting there required four fixes that are worth knowing about if you write your own
loader against this schema:

이 스키마에 대해 직접 로더를 작성한다면 알아둘 만한 네 가지 수정이 필요했습니다.

1. **Column order.** StarRocks requires the duplicate-key columns to lead the table, so
   its `CREATE TABLE` reorders **all six fact tables** relative to the TPC-DS field
   order dsdgen writes. A positional load writes `ss_ticket_number` into `ss_item_sk`.
   The loader sends an explicit `columns:` header built from the canonical order.
   **컬럼 순서.** StarRocks 는 duplicate-key 컬럼이 앞에 와야 하므로 `CREATE TABLE` 이
   **6개 팩트 테이블 전부**를 dsdgen 의 TPC-DS 필드 순서와 다르게 재배열합니다. 위치
   기반 적재는 `ss_ticket_number` 를 `ss_item_sk` 에 기록합니다. 로더는 표준 순서로
   만든 명시적 `columns:` 헤더를 전송합니다.
2. **`PUT`, not `POST`.** Stream Load requires an HTTP PUT with a known
   Content-Length. `curl --data-binary` sends POST and the FE answers
   `{"status":"FAILED","msg":"Not implemented"}`; piping from stdin makes curl use
   chunked encoding, which is also rejected. Use `--upload-file`.
   **`POST` 가 아니라 `PUT`.** Stream Load 는 Content-Length 가 확정된 HTTP PUT 을
   요구합니다. `curl --data-binary` 는 POST 를 보내 FE 가 "Not implemented" 로
   응답하고, stdin 파이프는 chunked 인코딩이 되어 역시 거부됩니다. `--upload-file` 을
   사용하십시오.
3. **Trailing delimiter.** dsdgen ends every line with `|`, which Stream Load counts as
   an extra column: every row is rejected as "too many filtered rows".
   **마지막 구분자.** dsdgen 은 각 줄을 `|` 로 끝내는데 Stream Load 는 이를 추가 컬럼으로
   계산해 모든 행을 "too many filtered rows" 로 거부합니다.
4. **The `call_center` partition clause.** See below.
   **`call_center` 파티션 절.** 아래 참고.

{: .warning }
> The upstream `call_center` DDL carries
> `partition by range(cc_rec_start_date) (START ("2023-06-01") END ("2023-07-01") ...)`.
> No TPC-DS row can satisfy it — dsdgen writes `cc_rec_start_date` in 1998–2002, so
> every row falls outside the range and the load rejects all of them. Upstream uses
> these files as planner-test fixtures, never as a load target, so the clause is
> harmless there and fatal here. `tools/sync-upstream.sh` removes it as a documented
> adaptation, leaving an unpartitioned table like the other 23.
>
> 상류 `call_center` DDL 에는
> `partition by range(cc_rec_start_date) (START ("2023-06-01") END ("2023-07-01") ...)`
> 가 있습니다. 어떤 TPC-DS 행도 이를 만족할 수 없습니다. dsdgen 은
> `cc_rec_start_date` 를 1998~2002 년으로 기록하므로 모든 행이 범위를 벗어나 적재가 전부
> 거부됩니다. 상류는 이 파일을 적재 대상이 아니라 플래너 테스트 픽스처로 쓰므로 그쪽에서는
> 무해하지만 여기서는 치명적입니다. `tools/sync-upstream.sh` 가 문서화된 변환으로 이를
> 제거해 나머지 23개처럼 파티션 없는 테이블로 만듭니다.

## Setup / 설정

```bash
docker compose -f docker/docker-compose.yml --profile starrocks up -d
# The all-in-one image takes ~90s to become ready / 올인원 이미지는 준비까지 약 90초
cp config/starrocks.env.example config/starrocks.env

bin/ddl.sh  --engine starrocks --create-database
bin/load.sh --engine starrocks --data-dir ~/tpcds/sf1
bin/run.sh  --engine starrocks --sf 1 --warmup 1 --iterations 3
```

Two ports matter: **9030** for the MySQL protocol (queries) and **8030** for the FE
HTTP endpoint (Stream Load). Both must be reachable.

두 개의 포트가 중요합니다. **9030** 은 MySQL 프로토콜(쿼리), **8030** 은 FE HTTP
엔드포인트(Stream Load)입니다. 둘 다 접근 가능해야 합니다.

## Schema / 스키마

The upstream DDL carries StarRocks physical design in each `CREATE TABLE`:

상류 DDL 은 각 `CREATE TABLE` 에 StarRocks 물리 설계를 포함합니다.

```sql
duplicate key (ss_item_sk, ss_ticket_number)
distributed by hash(ss_item_sk, ss_ticket_number) buckets 192
properties("replication_num" = "1")
```

{: .warning }
> **`buckets 192` suits a large cluster, not a laptop.** On a single BE it
> over-partitions the data and adds scheduling overhead that dominates at small scale
> factors. Either remove the `buckets` clause so StarRocks 3.x chooses for itself, or
> set it to roughly (BE count × cores) / 2.
>
> **`buckets 192` 는 대규모 클러스터 기준이며 노트북용이 아닙니다.** 단일 BE 에서는
> 과도한 분할이 되고, 작은 스케일 팩터에서는 스케줄링 오버헤드가 지배적입니다.
> `buckets` 절을 제거해 StarRocks 3.x 가 자동으로 정하게 하거나, 대략
> (BE 수 × 코어 수) / 2 로 설정하십시오.

`replication_num = 1` is correct for a single-BE setup and must be raised for a real
cluster.

`replication_num = 1` 은 단일 BE 구성에 맞으며, 실제 클러스터에서는 값을 올려야
합니다.

## Loading / 적재

Stream Load over HTTP against the FE. It is synchronous, returns a JSON status per
request, and needs no broker, which makes it the right tool for local files.

FE 에 HTTP Stream Load 를 수행합니다. 동기식이고 요청당 JSON 상태를 반환하며 broker 가
필요 없어 로컬 파일 적재에 적합합니다.

Two details worth knowing:

알아둘 두 가지:

- The FE replies with a **307 redirect to a BE**, so `curl` must be allowed to follow
  it and re-send the body. `load.sh` uses `--location-trusted`; plain `--location`
  drops the credentials on the redirect and the load fails with 401.
  FE 가 **BE 로 307 리다이렉트**하므로 `curl` 이 이를 따라가며 본문을 재전송해야
  합니다. `load.sh` 는 `--location-trusted` 를 사용합니다. 단순 `--location` 은
  리다이렉트에서 인증 정보를 버려 401 로 실패합니다.
- Each request carries a **label** derived from the file checksum, which makes the
  load idempotent: replaying the same file is rejected as a duplicate instead of
  double-inserting.
  각 요청은 파일 체크섬에서 파생한 **레이블**을 포함해 적재가 멱등해집니다. 같은
  파일을 재실행하면 중복으로 거부되어 이중 삽입을 막습니다.

A `Publish Timeout` status is treated as success: the data was written and the commit
is being published asynchronously.

`Publish Timeout` 상태는 성공으로 처리합니다. 데이터는 기록되었고 커밋이 비동기로
게시되는 중입니다.

`max_filter_ratio:0` means any malformed row fails the whole request rather than being
silently dropped.

`max_filter_ratio:0` 은 잘못된 행이 하나라도 있으면 조용히 버리지 않고 요청 전체를
실패시킵니다.

## Statistics / 통계

StarRocks collects statistics automatically, but `load.sh` runs an explicit
`ANALYZE TABLE` pass after loading so the first queries are not planned against stale
estimates. `engines/starrocks/tuning/stats.sql` does the same on demand and ends with
`SHOW ANALYZE STATUS` so you can confirm it landed.

StarRocks 는 통계를 자동 수집하지만, `load.sh` 는 적재 후 명시적으로 `ANALYZE TABLE`
을 수행해 첫 쿼리들이 오래된 추정치로 계획되지 않게 합니다.
`engines/starrocks/tuning/stats.sql` 이 같은 작업을 수행하고 마지막에
`SHOW ANALYZE STATUS` 로 결과를 확인합니다.

There are no secondary indexes to create — the physical design is entirely in the
`DUPLICATE KEY` and `DISTRIBUTED BY HASH` clauses.

생성할 보조 인덱스가 없습니다. 물리 설계는 전부 `DUPLICATE KEY` 와
`DISTRIBUTED BY HASH` 절에 있습니다.
