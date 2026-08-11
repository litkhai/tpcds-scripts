# PostgreSQL — TPC-DS

Schema derived by `tools/derive-ddl.sh`; queries derived by `tools/sync-upstream.sh`. Verified 103/103.

스키마는 `tools/derive-ddl.sh`, 쿼리는 `tools/sync-upstream.sh` 가 파생. 103/103 검증 완료.

**Full guide / 상세 안내: [`docs/engines/postgres.md`](../../docs/engines/postgres.md)**

## Contents / 구성

| Path | Contents / 내용 |
| --- | --- |
| `ddl/schema.sql` | TPC-DS schema / TPC-DS 스키마 |
| `queries/` | 103 query files / 쿼리 파일 103개 |
| `load/load.sh` | bulk loader, called by `bin/load.sh` / `bin/load.sh` 가 호출하는 벌크 로더 |
| `tuning/indexes.sql` | see the guide / 안내 참고 |

## Usage / 사용법

```bash
cp config/postgres.env.example config/postgres.env
bin/ddl.sh  --engine postgres
bin/load.sh --engine postgres --data-dir <dir>
bin/run.sh  --engine postgres --sf <n>
```

Do not hand-edit `ddl/` or `queries/` — they are generated. Change `tools/sync-upstream.sh`
or `tools/derive-ddl.sh` and re-run. See [`CONTRIBUTING.md`](../../CONTRIBUTING.md).

`ddl/` 와 `queries/` 는 생성물이므로 직접 수정하지 마십시오. `tools/sync-upstream.sh` 또는
`tools/derive-ddl.sh` 를 수정하고 재실행하십시오. [`CONTRIBUTING.md`](../../CONTRIBUTING.md) 참고.

Licensing and provenance: [`NOTICE.md`](../../NOTICE.md)
라이선스 및 출처: [`NOTICE.md`](../../NOTICE.md)
