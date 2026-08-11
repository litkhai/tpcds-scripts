# ClickHouse — TPC-DS

Imported verbatim from `ClickHouse/ClickHouse` `tests/benchmarks/tpc-ds/` (Apache-2.0).

`ClickHouse/ClickHouse` `tests/benchmarks/tpc-ds/` (Apache-2.0) 에서 그대로 임포트.

**Full guide / 상세 안내: [`docs/engines/clickhouse.md`](../../docs/engines/clickhouse.md)**

## Contents / 구성

| Path | Contents / 내용 |
| --- | --- |
| `ddl/schema.sql` | TPC-DS schema, 24 tables / TPC-DS 스키마, 24개 테이블 |
| `queries/` | 103 query files / 쿼리 파일 103개 |
| `load/load.sh` | bulk loader, called by `bin/load.sh` / `bin/load.sh` 가 호출하는 벌크 로더 |
| `reference/upstream-known-issues.md` | upstream's list of queries that need a workaround / 우회가 필요한 쿼리 목록(상류 원문) |
| `reference/upstream-settings.json` | settings the ClickHouse project uses for its own runs / ClickHouse 프로젝트가 자체 실행에 쓰는 설정 |

There is no `tuning/` directory: ClickHouse does not use table statistics the way a
cost-based optimiser does, and the physical design is already in the schema's
`PRIMARY KEY` clauses, which imply the `ORDER BY`.

`tuning/` 디렉터리가 없습니다. ClickHouse 는 비용 기반 옵티마이저처럼 테이블 통계를
사용하지 않으며, 물리 설계는 이미 스키마의 `PRIMARY KEY` 절(즉 `ORDER BY`)에
있습니다.

## Usage / 사용법

```bash
cp config/clickhouse.env.example config/clickhouse.env
bin/ddl.sh  --engine clickhouse --create-database
bin/load.sh --engine clickhouse --data-dir <dir>
bin/run.sh  --engine clickhouse --sf <n>
```

Read `reference/upstream-known-issues.md` before treating a query failure as a bug
here — q17, q35, q47, q57, q58 and q75 have known upstream caveats.

쿼리 실패를 이 저장소의 버그로 판단하기 전에 `reference/upstream-known-issues.md` 를
확인하십시오. q17, q35, q47, q57, q58, q75 에 알려진 상류 주의 사항이 있습니다.

Do not hand-edit `ddl/` or `queries/` — they are generated. Change `tools/sync-upstream.sh`
and re-run. See [`CONTRIBUTING.md`](../../CONTRIBUTING.md).

`ddl/` 와 `queries/` 는 생성물이므로 직접 수정하지 마십시오. `tools/sync-upstream.sh` 를
수정하고 재실행하십시오. [`CONTRIBUTING.md`](../../CONTRIBUTING.md) 참고.

Licensing and provenance: [`NOTICE.md`](../../NOTICE.md)
라이선스 및 출처: [`NOTICE.md`](../../NOTICE.md)
