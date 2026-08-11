# Oracle — TPC-DS

Repo-native assets: Oracle-dialect queries (`rownum`, `to_date(...) + N`) and SQL*Loader control files.

리포 고유 자산: Oracle 방언 쿼리(`rownum`, `to_date(...) + N`)와 SQL*Loader 컨트롤 파일.

**Full guide / 상세 안내: [`docs/engines/oracle.md`](../../docs/engines/oracle.md)**

## Contents / 구성

| Path | Contents / 내용 |
| --- | --- |
| `ddl/schema.sql` | TPC-DS schema / TPC-DS 스키마 |
| `queries/` | 103 query files / 쿼리 파일 103개 |
| `load/load.sh` | bulk loader, called by `bin/load.sh` / `bin/load.sh` 가 호출하는 벌크 로더 |
| `load/ctl/` | 24 SQL*Loader templates / SQL*Loader 템플릿 24개 |
| `tuning/indexes.sql` | see the guide / 안내 참고 |
| `tuning/stats.sql` | see the guide / 안내 참고 |

## Usage / 사용법

```bash
cp config/oracle.env.example config/oracle.env
bin/ddl.sh  --engine oracle
bin/load.sh --engine oracle --data-dir <dir>
bin/run.sh  --engine oracle --sf <n>
```

Edit these files directly — they are repo-native.

리포 고유 자산이므로 직접 수정합니다.

Licensing and provenance: [`NOTICE.md`](../../NOTICE.md)
라이선스 및 출처: [`NOTICE.md`](../../NOTICE.md)
