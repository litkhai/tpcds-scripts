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
