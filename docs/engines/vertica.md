---
title: Vertica
layout: default
parent: Engines
nav_order: 3
---

# Vertica

Vertica is the one engine with no well-licensed upstream TPC-DS source available, so
its query set is **derived here** from the same standard query text used for
PostgreSQL, and its schema from the repo's Oracle schema.

Vertica 는 라이선스가 명확한 상류 TPC-DS 소스가 없는 유일한 엔진입니다. 따라서 쿼리
세트는 PostgreSQL 과 동일한 표준 쿼리 원문에서 **여기서 파생**했고, 스키마는 리포의
Oracle 스키마에서 파생했습니다.

## Why derived rather than imported / 임포트하지 않고 파생한 이유

The candidate GitHub repositories carrying Vertica TPC-DS scripts have either no
licence file at all or `NOASSERTION`, which means there is no grant to rely on.
`vertica/Vertica-Extension-Packages` is `NOASSERTION` and is not a TPC-DS source
anyway. Deriving from the Apache-2.0 base and documenting the change is the honest
route. See [`NOTICE.md`](https://github.com/litkhai/tpcds-scripts/blob/master/NOTICE.md).

Vertica TPC-DS 스크립트를 담은 GitHub 리포지토리 후보들은 라이선스 파일이 아예 없거나
`NOASSERTION` 이어서 근거로 삼을 허여가 없습니다. `vertica/Vertica-Extension-Packages`
는 `NOASSERTION` 이며 애초에 TPC-DS 소스도 아닙니다. Apache-2.0 베이스에서 파생하고
변경 내용을 문서화하는 것이 정직한 방법입니다.
[`NOTICE.md`](https://github.com/litkhai/tpcds-scripts/blob/master/NOTICE.md) 참고.

{: .note }
> **The Vertica set has not been executed** — see the image note under Setup. The
> adaptations are the same two applied to PostgreSQL, which verified at 103/103, and
> Vertica accepts standard `DATE + INTEGER` arithmetic, `LIMIT`, `GROUP BY ROLLUP`,
> `GROUPING()` and `stddev_samp`. Expect it to work, but treat it as untested until you
> run it. If you have an image, `VERTICA_IMAGE=<image> tools/verify.sh --engine vertica`
> will do the whole check and write `results/verification.md`.
>
> **Vertica 세트는 실행하지 않았습니다.** Setup 의 이미지 안내를 참고하십시오. 변환 내용은
> 103/103 으로 검증된 PostgreSQL 과 동일한 두 가지이며, Vertica 는 표준
> `DATE + INTEGER` 연산, `LIMIT`, `GROUP BY ROLLUP`, `GROUPING()`, `stddev_samp` 를
> 지원합니다. 동작할 것으로 예상되지만 직접 실행하기 전까지는 미검증으로 취급하십시오.
> 이미지가 있다면 `VERTICA_IMAGE=<image> tools/verify.sh --engine vertica` 로 전체 검사를
> 수행하고 `results/verification.md` 를 생성할 수 있습니다.

## Setup / 설정

{: .warning }
> **There is no anonymously pullable Vertica image.** `vertica/vertica-ce` no longer
> exists on Docker Hub, and since the OpenText acquisition the only public image is
> `opentext/vertica-k8s`, which expects to be driven by the VerticaDB operator rather
> than started as a single container. The compose profile therefore takes the image from
> `VERTICA_IMAGE`; without it, starting the profile fails by design. Everything else in
> this repository works against any reachable Vertica.
>
> **익명으로 받을 수 있는 Vertica 이미지가 없습니다.** `vertica/vertica-ce` 는 Docker Hub
> 에서 사라졌고, OpenText 인수 이후 공개된 이미지는 단일 컨테이너로 기동하는 대신
> VerticaDB 오퍼레이터로 구동되는 `opentext/vertica-k8s` 뿐입니다. 따라서 compose 프로필은
> `VERTICA_IMAGE` 에서 이미지를 받으며, 지정하지 않으면 의도적으로 실패합니다. 그 외
> 모든 기능은 접근 가능한 어떤 Vertica 에 대해서도 동작합니다.

Vertica Community Edition allows 3 nodes and 1 TB of raw data, ample for SF 1–100, if
you have access to an image or an existing installation.

이미지나 기존 설치 환경에 접근할 수 있다면, Vertica Community Edition 은 노드 3개와 원본
데이터 1 TB 를 허용하며 SF 1~100 에 충분합니다.

```bash
# With an image you have access to / 접근 가능한 이미지가 있는 경우
export VERTICA_IMAGE=<your-vertica-image>
docker compose -f docker/docker-compose.yml --profile vertica up -d

# Or point config/vertica.env at an existing installation
# 또는 config/vertica.env 를 기존 설치 환경으로 지정
cp config/vertica.env.example config/vertica.env

# Vertica has no CREATE DATABASE step here — the image creates it at startup
# 여기서는 CREATE DATABASE 단계가 없습니다. 이미지가 기동 시 생성합니다
bin/ddl.sh  --engine vertica
bin/load.sh --engine vertica --data-dir ~/tpcds/sf1
bin/run.sh  --engine vertica --sf 1 --warmup 1 --iterations 3
```

## Dialect adaptations / 방언 변환

Identical to PostgreSQL, applied by `tools/sync-upstream.sh`:

PostgreSQL 과 동일하며 `tools/sync-upstream.sh` 가 적용합니다.

1. `date_add(cast('2000-08-23' as date), 30)` → `(cast('2000-08-23' as date) + 30)`,
   with negative offsets emitted as `- 30` (q21, q40).
   음수 오프셋은 `- 30` 으로 출력됩니다 (q21, q40).
2. The `ORDER BY` alias `lochierarchy` in q36, q70 and q86 is replaced with its
   defining expression, since standard SQL does not allow an output alias inside a
   larger `ORDER BY` expression.
   q36·q70·q86 의 `ORDER BY` 별칭 `lochierarchy` 를 정의식으로 치환합니다. 표준 SQL 은
   더 큰 `ORDER BY` 식 안에서 출력 별칭을 허용하지 않습니다.

## Schema and physical design / 스키마 및 물리 설계

`ddl/schema.sql` creates the 25 tables. **That is not the whole story on Vertica.**

`ddl/schema.sql` 이 25개 테이블을 생성합니다. **Vertica 에서는 이것만으로 끝이
아닙니다.**

Vertica has no indexes. Performance comes from **projections**: the sort order,
encoding and segmentation of each table's stored copy. `CREATE TABLE` alone produces
a superprojection whose sort order is simply the column order, which is rarely what
the TPC-DS joins want.

Vertica 에는 인덱스가 없습니다. 성능은 **프로젝션**, 즉 각 테이블 저장본의 정렬
순서·인코딩·세그먼테이션에서 나옵니다. `CREATE TABLE` 만 실행하면 컬럼 순서를 정렬
순서로 갖는 슈퍼프로젝션이 생기는데, 이는 TPC-DS 조인이 원하는 형태가 아닙니다.

`engines/vertica/tuning/projections.sql` deliberately ships **guidance rather than
hand-written projections**, because a projection design that is not derived from the
actual query set and data distribution is a guess. Use Database Designer:

`engines/vertica/tuning/projections.sql` 은 의도적으로 **손으로 쓴 프로젝션 대신
안내**를 제공합니다. 실제 쿼리 세트와 데이터 분포에서 도출되지 않은 프로젝션 설계는
추측일 뿐이기 때문입니다. Database Designer 를 사용하십시오.

```bash
admintools -t create_design -d tpcds -s comprehensive \
  -q engines/vertica/queries -o /tmp/tpcds-design
```

Or from SQL:

```sql
SELECT DESIGNER_CREATE_DESIGN('tpcds_design');
SELECT DESIGNER_ADD_DESIGN_TABLES('tpcds_design', 'public.*');
SELECT DESIGNER_ADD_DESIGN_QUERIES('tpcds_design', '/path/to/queries.sql', true);
SELECT DESIGNER_SET_DESIGN_TYPE('tpcds_design', 'COMPREHENSIVE');
SELECT DESIGNER_RUN_POPULATE_DESIGN_AND_DEPLOY(
         'tpcds_design', '/tmp/design.sql', '/tmp/deploy.sql');
```

The file also contains a commented example projection for `store_sales` — segmented on
the primary key, with `RLE` on `ss_sold_date_sk` — to show the shape. It is commented
out because it only makes sense on a multi-node cluster and it replaces the
superprojection.

이 파일에는 형태를 보여주기 위해 `store_sales` 에 대한 주석 처리된 예시 프로젝션도
있습니다(기본키로 세그먼트, `ss_sold_date_sk` 에 `RLE`). 다중 노드 클러스터에서만
의미가 있고 슈퍼프로젝션을 대체하므로 주석 처리했습니다.

## Loading / 적재

`COPY ... FROM STDIN DELIMITER '|' NULL '' DIRECT ABORT ON ERROR`, reading from stdin
so it works whether `vsql` runs on the Vertica node or remotely. A server-side `COPY`
would require the `.dat` files to be on the node itself.

`COPY ... FROM STDIN DELIMITER '|' NULL '' DIRECT ABORT ON ERROR` 로 stdin 에서
읽으므로 `vsql` 이 Vertica 노드에서 실행되든 원격이든 동작합니다. 서버 측 `COPY` 는
`.dat` 파일이 노드에 있어야 합니다.

`DIRECT` loads straight into ROS containers. On Vertica 12 and later, where the WOS was
removed, it is accepted but no longer changes behaviour; it is kept for compatibility
with older versions.

`DIRECT` 는 ROS 컨테이너에 직접 적재합니다. WOS 가 제거된 Vertica 12 이상에서는
허용되지만 동작에 영향이 없으며, 구버전 호환을 위해 유지합니다.

Rejected rows and their reasons are written per table to `$LOG_DIR/<table>.rejected`
and `.exceptions`, so a bad load can be diagnosed instead of silently under-counting.

거부된 행과 사유는 테이블별로 `$LOG_DIR/<table>.rejected` 와 `.exceptions` 에
기록되어, 조용히 행이 누락되는 대신 원인을 진단할 수 있습니다.

`load.sh` then runs `ANALYZE_STATISTICS` per table. This is mandatory — without it the
optimiser has no cardinality estimates for the fact tables and picks unusable join
orders.

이후 `load.sh` 가 테이블별로 `ANALYZE_STATISTICS` 를 실행합니다. 필수입니다. 없으면
옵티마이저가 팩트 테이블 카디널리티를 추정할 수 없어 사용할 수 없는 조인 순서를
선택합니다.
