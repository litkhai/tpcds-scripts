# StarRocks — TPC-DS

Imported verbatim from `StarRocks/starrocks` `fe/fe-core/src/test/resources/sql/tpcds/`
(Apache-2.0). This set is also the base for the PostgreSQL and Vertica query sets,
because it carries the plain TPC-DS qualification query text.

`StarRocks/starrocks` `fe/fe-core/src/test/resources/sql/tpcds/` (Apache-2.0) 에서
그대로 임포트. 표준 TPC-DS qualification 쿼리 원문을 담고 있어 PostgreSQL 과 Vertica
쿼리 세트의 베이스이기도 합니다.

**Full guide / 상세 안내: [`docs/engines/starrocks.md`](../../docs/engines/starrocks.md)**

## Contents / 구성

| Path | Contents / 내용 |
| --- | --- |
| `ddl/schema.sql` | 24 per-table DDL files concatenated / 테이블별 DDL 24개를 연결 |
| `queries/` | 103 query files / 쿼리 파일 103개 |
| `load/load.sh` | Stream Load over HTTP, called by `bin/load.sh` / `bin/load.sh` 가 호출하는 HTTP Stream Load |
| `tuning/stats.sql` | `ANALYZE TABLE` for all 24 tables / 24개 테이블 `ANALYZE TABLE` |

## Usage / 사용법

```bash
cp config/starrocks.env.example config/starrocks.env
bin/ddl.sh  --engine starrocks --create-database
bin/load.sh --engine starrocks --data-dir <dir>
bin/run.sh  --engine starrocks --sf <n>
```

Two ports are needed: **9030** for the MySQL protocol (queries) and **8030** for the
FE HTTP endpoint (Stream Load).

두 개의 포트가 필요합니다. **9030** 은 MySQL 프로토콜(쿼리), **8030** 은 FE HTTP
엔드포인트(Stream Load)입니다.

> **`buckets 192` in the upstream schema suits a large cluster, not a laptop.** On a
> single BE it over-partitions the data. Remove the clause so StarRocks 3.x chooses
> for itself, or set it to roughly (BE count × cores) / 2.
>
> **상류 스키마의 `buckets 192` 는 대규모 클러스터 기준이며 노트북용이 아닙니다.**
> 단일 BE 에서는 과도한 분할이 됩니다. 절을 제거해 StarRocks 3.x 가 자동으로 정하게
> 하거나 대략 (BE 수 × 코어 수) / 2 로 설정하십시오.

Do not hand-edit `ddl/` or `queries/` — they are generated. Change `tools/sync-upstream.sh`
and re-run. See [`CONTRIBUTING.md`](../../CONTRIBUTING.md).

`ddl/` 와 `queries/` 는 생성물이므로 직접 수정하지 마십시오. `tools/sync-upstream.sh` 를
수정하고 재실행하십시오. [`CONTRIBUTING.md`](../../CONTRIBUTING.md) 참고.

Licensing and provenance: [`NOTICE.md`](../../NOTICE.md)
라이선스 및 출처: [`NOTICE.md`](../../NOTICE.md)
