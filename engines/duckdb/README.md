# DuckDB — TPC-DS

Schema derived by `tools/derive-ddl.sh`; queries derived by `tools/sync-upstream.sh` — the
PostgreSQL query set, with a DuckDB-only fix in q77 and q90. Verified 103/103 on DuckDB v1.5.6
(2026-10-09).

스키마는 `tools/derive-ddl.sh`, 쿼리는 `tools/sync-upstream.sh` 가 파생. PostgreSQL 쿼리 세트에
q77·q90 의 DuckDB 전용 수정만 더했습니다. DuckDB v1.5.6 에서 103/103 검증(2026-10-09).

**Full guide / 상세 안내: [`docs/engines/duckdb.md`](../../docs/engines/duckdb.md)**

## Contents / 구성

| Path | Contents / 내용 |
| --- | --- |
| `ddl/schema.sql` | TPC-DS schema / TPC-DS 스키마 |
| `queries/` | 103 query files / 쿼리 파일 103개 |
| `load/load.sh` | bulk loader, called by `bin/load.sh` / `bin/load.sh` 가 호출하는 벌크 로더 |

## Usage / 사용법

```bash
cp config/duckdb.env.example config/duckdb.env    # optional / 선택
bin/ddl.sh  --engine duckdb
bin/load.sh --engine duckdb --data-dir <dir>
bin/run.sh  --engine duckdb --sf <n>
```

The `duckdb` CLI must be on `PATH`; there is no container. / `duckdb` CLI 가 `PATH` 에 있어야 하며
컨테이너는 없습니다.

Do not hand-edit `ddl/` or `queries/` — they are generated. Change `tools/sync-upstream.sh`
or `tools/derive-ddl.sh` and re-run. See [`CONTRIBUTING.md`](../../CONTRIBUTING.md).

`ddl/` 와 `queries/` 는 생성물이므로 직접 수정하지 마십시오. `tools/sync-upstream.sh` 또는
`tools/derive-ddl.sh` 를 수정하고 재실행하십시오. [`CONTRIBUTING.md`](../../CONTRIBUTING.md) 참고.

Licensing and provenance: [`NOTICE.md`](../../NOTICE.md)
라이선스 및 출처: [`NOTICE.md`](../../NOTICE.md)
