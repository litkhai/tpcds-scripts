# Verification / 검증

## Run it / 실행 방법

```bash
tools/verify.sh --all              # postgres, clickhouse, starrocks
tools/verify.sh --engine postgres
tools/verify.sh --engine clickhouse --keep    # leave the container up / 컨테이너 유지
```

No TPC EULA acceptance and no local database client are needed: the engines and their
clients both run in containers, and the data is synthetic.

TPC EULA 동의도, 로컬 데이터베이스 클라이언트도 필요하지 않습니다. 엔진과 클라이언트가
모두 컨테이너에서 실행되고 데이터는 합성 데이터입니다.

For each engine `tools/verify.sh`:

각 엔진에 대해 `tools/verify.sh` 는 다음을 수행합니다.

1. removes any previous container **and volume**, so the run starts from an empty
   database / 이전 컨테이너와 **볼륨**을 제거해 빈 데이터베이스에서 시작
2. starts the engine from `docker/docker-compose.yml` and waits for its healthcheck
   / `docker/docker-compose.yml` 로 엔진을 기동하고 헬스체크를 대기
3. applies `engines/<engine>/ddl/schema.sql` via `bin/ddl.sh`
4. loads the fixture via `bin/load.sh` / `bin/load.sh` 로 픽스처 적재
5. runs all 103 queries via `bin/run.sh --continue-on-error`
6. writes `results/verification.md` and `results/verify-<engine>.csv`

The same thing runs in CI on every push — see `.github/workflows/verify.yml`.

CI 에서도 push 마다 동일하게 실행됩니다. `.github/workflows/verify.yml` 참고.

## What it proves, and what it does not / 증명하는 것과 하지 않는 것

| ✅ Proves / 증명 | ✖ Does not prove / 미증명 |
| --- | --- |
| The schema applies on this engine / 스키마가 적용된다 | That answers are **correct**. The official TPC-DS answer sets are TPC EULA material and are not available here. / 정답이 **맞는지**. 공식 정답 세트는 TPC EULA 자산이라 사용할 수 없습니다. |
| The bulk loader works end to end / 로더가 처음부터 끝까지 동작한다 | Anything about **performance**. The fixture is tiny and runs in a container with shared CPU. / **성능**에 대한 어떤 것도. 픽스처가 매우 작고 CPU 를 공유하는 컨테이너에서 실행됩니다. |
| Every query parses and executes against real rows / 모든 쿼리가 실제 행에 대해 파싱·실행된다 | That the engine handles a realistic data distribution / 현실적인 데이터 분포를 처리하는지 |

To compare answers across engines, use `bin/run.sh --keep-output` on two engines at
the same scale factor and diff the result files — see
[Methodology](../reference/methodology.md). Where the schemas themselves disagree, see
[Schema divergence](schema-divergence.md).

엔진 간 정답을 비교하려면 동일 스케일 팩터에서 두 엔진에 `bin/run.sh --keep-output` 을
사용하고 결과 파일을 diff 하십시오. [방법론](../reference/methodology.md) 참고.

## The fixture / 픽스처

`tools/make-fixture.py` writes ~140,000 rows across all 24 tables (~11 MB) in the
dsdgen output format. It is **not** TPC-DS data — it is our own synthetic data, which is
what makes verification runnable without the toolkit.

`tools/make-fixture.py` 는 dsdgen 출력 형식으로 24개 테이블에 약 140,000 행(~11 MB)을
생성합니다. TPC-DS 데이터가 **아니라** 자체 합성 데이터이며, 그래서 툴킷 없이도 검증을
실행할 수 있습니다.

Three properties make it usable as a load target:

적재 대상으로 사용 가능하게 하는 세 가지 속성:

- **Column lists come from the DDL,** not from a hardcoded list, so the field count and
  declared sizes always match the schema. / **컬럼 목록을 DDL 에서 읽으므로** 필드 수와
  선언 크기가 항상 스키마와 일치합니다.
- **`NOT NULL` is honoured.** An empty field in a `NOT NULL` column fails the load on
  every engine that enforces it. / **`NOT NULL` 을 준수합니다.**
- **Composite primary keys are unique by construction.** The six fact tables declare
  keys like `(ss_item_sk, ss_ticket_number)`; drawing both randomly collides within a
  few thousand rows, so they are derived from the row index instead. / **복합 기본키가
  구조적으로 유일합니다.** 두 값을 무작위로 뽑으면 수천 행 안에 충돌하므로 행 인덱스에서
  유도합니다.

Dimension domains are seeded with the literal values the queries filter on — `'TN'`,
`'Books'`, `d_month_seq` counted from 1900-01 so that `1200` means January 2000 — so
that joins and predicates match something. That is the only sense in which the data
resembles TPC-DS.

차원 도메인은 쿼리가 필터하는 리터럴 값으로 채웁니다. `'TN'`, `'Books'`, 그리고
`1200` 이 2000년 1월을 의미하도록 1900-01 부터 계산한 `d_month_seq` 등입니다. 조인과
조건이 무언가와 매칭되게 하려는 것이고, 데이터가 TPC-DS 를 닮은 부분은 그것뿐입니다.

## Coverage / 검증 범위

| Engine / 엔진 | Verified / 검증 | Why not / 이유 |
| --- | --- | --- |
| PostgreSQL | ✅ automated | — |
| ClickHouse | ✅ automated | — |
| StarRocks | ✅ automated | — |
| Vertica | ⬜ manual only | No anonymously pullable image since the OpenText acquisition. `VERTICA_IMAGE=<image> tools/verify.sh --engine vertica` runs the full check if you have one. / OpenText 인수 이후 익명으로 받을 수 있는 이미지가 없습니다. |
| Oracle | ⬜ manual only | `container-registry.oracle.com` requires accepting the licence and authenticating. / 라이선스 동의와 인증이 필요합니다. |

Coverage limits are stated rather than hidden: an engine listed as unverified has had
its schema and queries imported or derived, but no run executed in this repository.

검증 범위의 한계를 숨기지 않고 명시합니다. 미검증으로 표시된 엔진은 스키마와 쿼리를
임포트·파생했지만 이 저장소에서 실행한 적은 없습니다.
