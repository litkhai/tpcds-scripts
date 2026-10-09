# Quick start / 빠른 시작

## Just checking it works / 동작만 확인하려면

No toolkit, no TPC EULA acceptance, no data generation, and no local database client:

툴킷도 TPC EULA 동의도 데이터 생성도 로컬 데이터베이스 클라이언트도 필요하지 않습니다.

```bash
tools/verify.sh --all
```

That starts each engine, applies the schema, loads a synthetic fixture and runs all 103
queries. See [Verification](../verification/index.md).

각 엔진을 기동해 스키마를 적용하고 합성 픽스처를 적재한 뒤 103개 쿼리를 전부 실행합니다.
[검증](../verification/index.md) 참고.

## A real run / 실제 실행

```bash
# 1. Start an engine / 엔진 기동
docker compose -f docker/docker-compose.yml --profile postgres up -d

# 2. Connection settings / 접속 설정
cp config/postgres.env.example config/postgres.env

# 3. Toolkit and data — prompts you to accept the TPC EULA
#    툴킷 및 데이터 — TPC EULA 동의를 요구합니다
datagen/fetch-toolkit.sh --community
datagen/generate.sh --sf 1 --out ~/tpcds/sf1

# 4. Schema and load / 스키마 생성 및 적재
bin/ddl.sh  --engine postgres
bin/load.sh --engine postgres --data-dir ~/tpcds/sf1

# 5. Run / 실행
bin/run.sh  --engine postgres --sf 1 --warmup 1 --iterations 3
```

Swap `postgres` for `oracle`, `vertica`, `clickhouse`, `starrocks` or `duckdb` — the commands are
identical. Results land in `results/<timestamp>-<engine>-sf<n>.csv`.

`postgres` 를 `oracle`, `vertica`, `clickhouse`, `starrocks`, `duckdb` 로 바꾸면 되며 명령은
동일합니다. 결과는 `results/<timestamp>-<engine>-sf<n>.csv` 에 저장됩니다.

## Per-engine notes / 엔진별 참고

=== "PostgreSQL"

    ```bash
    docker compose -f docker/docker-compose.yml --profile postgres up -d
    cp config/postgres.env.example config/postgres.env
    bin/ddl.sh  --engine postgres --create-database
    bin/load.sh --engine postgres --data-dir ~/tpcds/sf1
    bin/run.sh  --engine postgres --sf 1
    ```

    `bin/load.sh` runs `ANALYZE` at the end. Do not skip it — without statistics the
    planner picks nested loops for the fact joins and several queries become unusable.

    `bin/load.sh` 가 마지막에 `ANALYZE` 를 실행합니다. 생략하지 마십시오. 통계가 없으면
    플래너가 팩트 조인에 중첩 루프를 선택해 일부 쿼리를 사용할 수 없게 됩니다.

    [Full guide / 상세 안내](../engines/postgres.md)

=== "ClickHouse"

    ```bash
    docker compose -f docker/docker-compose.yml --profile clickhouse up -d
    cp config/clickhouse.env.example config/clickhouse.env
    bin/ddl.sh  --engine clickhouse --create-database
    bin/load.sh --engine clickhouse --data-dir ~/tpcds/sf1
    bin/run.sh  --engine clickhouse --sf 1
    ```

    The `CH_EXTRA_ARGS` in the example config are **required**, not tuning: three of
    them stop queries failing outright and three change results silently.

    예시 설정의 `CH_EXTRA_ARGS` 는 튜닝이 아니라 **필수**입니다. 세 개는 쿼리 실패를
    막고 세 개는 결과를 조용히 바꿉니다.

    [Full guide / 상세 안내](../engines/clickhouse.md)

=== "StarRocks"

    ```bash
    docker compose -f docker/docker-compose.yml --profile starrocks up -d
    # the all-in-one image needs ~30-60s before a BE registers
    # 올인원 이미지는 BE 등록까지 약 30~60초가 필요합니다
    cp config/starrocks.env.example config/starrocks.env
    bin/ddl.sh  --engine starrocks --create-database
    bin/load.sh --engine starrocks --data-dir ~/tpcds/sf1
    bin/run.sh  --engine starrocks --sf 1
    ```

    Two ports matter: **9030** for the MySQL protocol and **8030** for the FE HTTP
    endpoint that Stream Load uses.

    두 포트가 중요합니다. **9030** 은 MySQL 프로토콜, **8030** 은 Stream Load 가 쓰는
    FE HTTP 엔드포인트입니다.

    [Full guide / 상세 안내](../engines/starrocks.md)

=== "DuckDB"

    ```bash
    brew install duckdb        # no container; the database is one file
    bin/ddl.sh  --engine duckdb
    bin/load.sh --engine duckdb --data-dir ~/tpcds/sf1
    bin/run.sh  --engine duckdb --sf 1
    ```

    The queries are the PostgreSQL set, identical except q77 and q90. The database file
    defaults to `.data/tpcds.duckdb`; set `DUCKDB_DATABASE` in `config/duckdb.env` to move it.

    쿼리는 PostgreSQL 세트이며 q77·q90 을 제외하면 동일합니다. 데이터베이스 파일 기본값은
    `.data/tpcds.duckdb` 이고, `config/duckdb.env` 의 `DUCKDB_DATABASE` 로 옮길 수 있습니다.

    [Full guide / 상세 안내](../engines/duckdb.md)

=== "Oracle"

    There is no Docker profile — Oracle Database images are not redistributable under a
    licence this repository can assume. Create the user first:

    Docker 프로필이 없습니다. Oracle Database 이미지는 이 저장소가 전제할 수 있는
    라이선스로 재배포되지 않습니다. 먼저 사용자를 생성하십시오.

    ```sql
    CREATE USER tpcds IDENTIFIED BY tpcds;
    GRANT CONNECT, RESOURCE, CREATE VIEW TO tpcds;
    ALTER USER tpcds QUOTA UNLIMITED ON USERS;
    ```

    ```bash
    cp config/oracle.env.example config/oracle.env   # set ORACLE_CONNECT
    bin/ddl.sh  --engine oracle
    bin/load.sh --engine oracle --data-dir ~/tpcds/sf1
    bin/ddl.sh  --engine oracle --tuning     # DBMS_STATS — do not skip / 생략 금지
    bin/run.sh  --engine oracle --sf 1
    ```

    Both `sqlplus` **and** `sqlldr` must be on `PATH`; they ship in different Oracle
    Instant Client packages.

    `sqlplus` 와 `sqlldr` 이 **모두** `PATH` 에 있어야 하며, 서로 다른 Oracle Instant
    Client 패키지에 속합니다.

    [Full guide / 상세 안내](../engines/oracle.md)

=== "Vertica"

    No public Vertica CE image exists since the OpenText acquisition, so supply your own
    or point the config at an existing installation.

    OpenText 인수 이후 공개된 Vertica CE 이미지가 없으므로, 직접 이미지를 준비하거나
    기존 설치 환경을 설정에 지정하십시오.

    ```bash
    export VERTICA_IMAGE=<your-vertica-image>
    docker compose -f docker/docker-compose.yml --profile vertica up -d
    cp config/vertica.env.example config/vertica.env
    bin/ddl.sh  --engine vertica
    bin/load.sh --engine vertica --data-dir ~/tpcds/sf1
    bin/run.sh  --engine vertica --sf 1
    ```

    Vertica has no indexes — performance comes from projections. See the guide.

    Vertica 에는 인덱스가 없고 성능은 프로젝션에서 나옵니다. 안내를 참고하십시오.

    [Full guide / 상세 안내](../engines/vertica.md)

## Choosing a scale factor / 스케일 팩터 선택

| SF | Flat files / 플랫 파일 | Reasonable for / 적합한 용도 |
|:--|:--|:--|
| 1 | ~1 GB | correctness checks, laptop / 정합성 확인, 노트북 |
| 10 | ~10 GB | first performance impressions / 초기 성능 감각 |
| 100 | ~100 GB | single-node comparisons / 단일 노드 비교 |
| 1000+ | ~1 TB+ | cluster work; check free space first / 클러스터 작업, 여유 공간 먼저 확인 |

The loaded database is larger than the flat files. TPC-DS only defines the scale factors
1, 10, 100, 300, 1000, 3000, 10000 and above; `datagen/generate.sh` warns if you pass
anything else.

적재된 데이터베이스는 플랫 파일보다 큽니다. TPC-DS 는 1, 10, 100, 300, 1000, 3000, 10000
이상만 정의하며, 그 외 값을 넣으면 `datagen/generate.sh` 가 경고합니다.
