# Vertica — TPC-DS

Schema and queries derived here — no well-licensed upstream Vertica source exists. Not yet executed.

스키마·쿼리를 여기서 파생 — 라이선스가 명확한 상류 Vertica 소스가 없음. 미실행.

**Full guide / 상세 안내: [`docs/engines/vertica.md`](../../docs/engines/vertica.md)**

## Contents / 구성

| Path | Contents / 내용 |
| --- | --- |
| `ddl/schema.sql` | TPC-DS schema / TPC-DS 스키마 |
| `queries/` | 103 query files / 쿼리 파일 103개 |
| `load/load.sh` | bulk loader, called by `bin/load.sh` / `bin/load.sh` 가 호출하는 벌크 로더 |
| `tuning/projections.sql` | see the guide / 안내 참고 |

## Usage / 사용법

```bash
cp config/vertica.env.example config/vertica.env
bin/ddl.sh  --engine vertica
bin/load.sh --engine vertica --data-dir <dir>
bin/run.sh  --engine vertica --sf <n>
```

Do not hand-edit `ddl/` or `queries/` — they are generated. Change `tools/sync-upstream.sh`
or `tools/derive-ddl.sh` and re-run. See [`CONTRIBUTING.md`](../../CONTRIBUTING.md).

`ddl/` 와 `queries/` 는 생성물이므로 직접 수정하지 마십시오. `tools/sync-upstream.sh` 또는
`tools/derive-ddl.sh` 를 수정하고 재실행하십시오. [`CONTRIBUTING.md`](../../CONTRIBUTING.md) 참고.

Licensing and provenance: [`NOTICE.md`](../../NOTICE.md)
라이선스 및 출처: [`NOTICE.md`](../../NOTICE.md)
