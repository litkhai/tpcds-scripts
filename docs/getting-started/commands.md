# Commands / 명령

Three commands cover the whole workflow, and they take the same arguments for every
engine. Connection settings come from `config/<engine>.env`.

세 개의 명령이 전체 워크플로를 담당하며, 모든 엔진에서 동일한 인자를 받습니다. 접속
설정은 `config/<engine>.env` 에서 읽습니다.

## `bin/ddl.sh`

Create the schema, and optionally the tuning objects.

스키마를 생성하고 선택적으로 튜닝 오브젝트를 생성합니다.

| Flag | Meaning / 의미 |
|:---|:---|
| `--engine <name>` | `oracle` \| `postgres` \| `vertica` \| `clickhouse` \| `starrocks`, required / 필수 |
| `--create-database` | `CREATE DATABASE` first — postgres, clickhouse, starrocks / 데이터베이스 먼저 생성 |
| `--tuning` | also apply `engines/<engine>/tuning/*.sql` / 튜닝 스크립트도 적용 |
| `--drop` | `DROP` the 24 TPC-DS tables, then stop / 24개 테이블을 DROP 하고 종료 |

Oracle and Vertica have no `--create-database` step: Oracle expects a pre-created user
and Vertica a pre-created database.

Oracle 과 Vertica 에는 `--create-database` 단계가 없습니다. Oracle 은 미리 만든 사용자를,
Vertica 는 미리 만든 데이터베이스를 사용합니다.

!!! note "Note / 참고"

    Comments are stripped before the SQL reaches the engine. The `mysql` client
    (StarRocks) splits input on every `;`, including one inside a `--` comment, and then
    sends a comment-only fragment the server rejects.

    SQL 이 엔진에 도달하기 전에 주석을 제거합니다. `mysql` 클라이언트(StarRocks)는 `--`
    주석 안의 `;` 까지 포함해 모든 `;` 에서 입력을 분리하고, 주석만 남은 조각을 서버가
    거부합니다.

## `bin/load.sh`

Load dsdgen output using the engine's own bulk tool.

각 엔진의 벌크 도구로 dsdgen 출력물을 적재합니다.

| Flag | Meaning / 의미 |
|:---|:---|
| `--engine <name>` | required / 필수 |
| `--data-dir <dir>` | directory of `.dat` files, required / `.dat` 파일 디렉터리, 필수 |
| `--log-dir <dir>` | loader logs and rejected rows, default `<data-dir>/../load-logs` |
| `--tables <spec>` | `all` (default) or comma-separated names / `all` 또는 콤마 구분 이름 |

Tables load dimensions before facts, so a run with enforced referential integrity also
succeeds. Missing `.dat` files are reported before any load starts rather than halfway
through.

차원 테이블을 팩트보다 먼저 적재하므로 참조 정합성을 강제한 경우에도 성공합니다. `.dat`
파일 누락은 적재 도중이 아니라 시작 전에 보고합니다.

Per-engine bulk tool:

엔진별 벌크 도구:

| Engine | Tool / 도구 |
|:---|:---|
| Oracle | `sqlldr`, driven by the per-table `.ctl` templates / 테이블별 `.ctl` 템플릿 사용 |
| PostgreSQL | `COPY … FROM STDIN` |
| Vertica | `COPY … FROM STDIN DIRECT ABORT ON ERROR` |
| ClickHouse | `INSERT … FORMAT CSV` |
| StarRocks | Stream Load over HTTP `PUT` / HTTP `PUT` Stream Load |

## `bin/run.sh`

Execute queries and record timings.

쿼리를 실행하고 수행 시간을 기록합니다.

| Flag | Meaning / 의미 |
|:---|:---|
| `--engine <name>` | required / 필수 |
| `--queries <spec>` | `all` (default) \| `1,5,22` \| `1-10` \| `14_2` |
| `--iterations <n>` | measured runs per query, default 1 / 쿼리별 측정 횟수 |
| `--warmup <n>` | unmeasured runs first, default 0 / 측정 전 예열 횟수 |
| `--sf <n>` | scale factor, recorded in the CSV only / CSV 에만 기록되는 스케일 팩터 |
| `--out <file>` | results CSV path / 결과 CSV 경로 |
| `--keep-output` | keep result rows, for cross-engine diffing / 엔진 간 비교용 결과 행 보관 |
| `--continue-on-error` | do not stop at the first failure / 실패해도 계속 |

Output CSV columns:

출력 CSV 컬럼:

```text
run_stamp, engine, scale_factor, query, iteration, elapsed_ms, rows, status
```

Timing is wall-clock around the engine's own CLI, so it includes connection setup,
planning, execution and result transfer. That is deliberate — it is what a user waits
for — but it means these are not engine-internal execution times. See
[Methodology](../reference/methodology.md).

시간 측정은 각 엔진 CLI 호출을 감싼 실측 시간이므로 접속 설정·계획·실행·결과 전송이
포함됩니다. 사용자가 실제로 기다리는 시간이라는 점에서 의도적이지만, 엔진 내부 실행
시간은 아닙니다. [방법론](../reference/methodology.md) 참고.

## Tools / 도구

| Tool | Purpose / 용도 |
|:---|:---|
| `tools/verify.sh` | start engine, load fixture, run all 103, write a report / 엔진 기동·픽스처 적재·103개 실행·보고서 |
| `tools/sync-upstream.sh` | re-import upstream SQL at pinned commits / 핀 고정 커밋에서 상류 SQL 재임포트 |
| `tools/derive-ddl.sh` | generate the PostgreSQL and Vertica schemas / PostgreSQL·Vertica 스키마 생성 |
| `tools/make-fixture.py` | synthetic fixture data, no TPC EULA needed / 합성 픽스처, TPC EULA 불필요 |
| `tools/compare-schemas.py` | report where the five schemas disagree / 다섯 스키마 불일치 보고 |

`engines/*/queries/` and `engines/*/ddl/` are **generated**. To change a dialect
adaptation, edit `tools/sync-upstream.sh` and re-run it — a hand-edit makes the file's
provenance header a lie and disappears on the next sync. Oracle is the exception: those
files are repo-native and edited directly.

`engines/*/queries/` 와 `engines/*/ddl/` 은 **생성물**입니다. 방언 변환을 바꾸려면
`tools/sync-upstream.sh` 를 수정하고 재실행하십시오. 직접 수정하면 파일의 출처 헤더가
사실과 달라지고 다음 동기화에서 사라집니다. Oracle 은 예외로 리포 고유 자산이며 직접
수정합니다.
