# DuckDB

An embedded engine: no server, no container — the database is one file and the client is
the `duckdb` command-line tool. This engine exists first as a **local reference for
PostgreSQL-dialect SQL**: its query set is the PostgreSQL query set of this repository,
and 101 of the 103 files are byte-identical to `engines/postgres/queries/` below the
header.

임베디드 엔진입니다. 서버도 컨테이너도 없고, 데이터베이스는 파일 하나이며 클라이언트는
`duckdb` 명령줄 도구입니다. 이 엔진은 우선 **PostgreSQL 방언 SQL 의 로컬 기준**으로
존재합니다. 쿼리 세트는 이 저장소의 PostgreSQL 쿼리 세트이며, 103개 중 101개는 헤더 아래가
`engines/postgres/queries/` 와 바이트 단위로 같습니다.

## Verified / 검증 결과

`tools/verify.sh --engine duckdb`, measured 2026-10-09 on DuckDB v1.5.6 (`069cc9f9b5`,
Homebrew bottle, macOS 26.7.1, arm64), with the synthetic fixture from
`tools/make-fixture.py` (default seed and size):

2026-10-09 에 DuckDB v1.5.6(`069cc9f9b5`, Homebrew bottle, macOS 26.7.1, arm64)에서
`tools/make-fixture.py` 의 합성 픽스처(기본 seed·크기)로 측정한 `tools/verify.sh --engine duckdb`
결과:

| Check / 항목 | Result / 결과 |
| --- | --- |
| Schema applies | ✅ 25 tables |
| Fixture loads (row counts match the `.dat` line counts) | ✅ 24/24 tables |
| All 103 queries execute with data | ✅ **103/103** |
| Row count per query equals the PostgreSQL run on the same fixture | ✅ 103/103 (a coarse check, not an answer check) |

The CI job pins the Linux x86-64 CLI of the same release (v1.5.6); its result is in the
workflow run, not in this table.

CI 작업은 같은 릴리스(v1.5.6)의 Linux x86-64 CLI 를 고정해 사용합니다. 그 결과는 이 표가
아니라 워크플로 실행 결과에 있습니다.

On this fixture 47 of the 103 queries return zero rows (the fixture makes predicates match
*something*, not everything). They still prove the SQL parses, binds and executes; they say
nothing about the answer.

이 픽스처에서 103개 중 47개 쿼리는 0 행을 반환합니다(픽스처는 조건이 *일부* 매칭되도록 할 뿐
전부 매칭하지는 않습니다). 이 쿼리들도 SQL 이 파싱·바인딩·실행됨은 증명하지만 정답에 대해서는
아무것도 말하지 않습니다.

## Setup / 설정

```bash
brew install duckdb          # or https://duckdb.org/install/ / 또는 설치 안내 페이지
cp config/duckdb.env.example config/duckdb.env     # optional / 선택

bin/ddl.sh  --engine duckdb
bin/load.sh --engine duckdb --data-dir ~/tpcds/sf1
bin/run.sh  --engine duckdb --sf 1 --warmup 1 --iterations 3
```

`--create-database` is accepted and does nothing: DuckDB creates the file on first connect.

`--create-database` 는 허용되지만 아무 동작도 하지 않습니다. DuckDB 는 첫 접속 시 파일을
생성합니다.

## Configuration / 설정 값

`config/duckdb.env`:

| Variable / 변수 | Meaning / 의미 |
| --- | --- |
| `DUCKDB_DATABASE` | Database file. Unset: `<repo>/.data/tpcds.duckdb` (git-ignored). / 데이터베이스 파일. 미설정 시 `<repo>/.data/tpcds.duckdb`(git 제외). |
| `DUCKDB_THREADS` | Optional. Sent as `SET threads = N` on every connection. / 선택. 접속마다 `SET threads = N` 으로 전달. |
| `DUCKDB_MEMORY_LIMIT` | Optional. Sent as `SET memory_limit = '...'`. / 선택. `SET memory_limit = '...'` 으로 전달. |

`tools/verify.sh` exports its own `DUCKDB_DATABASE` (a temporary file), which wins over this
file, so a database you use is never touched by a verification run.

`tools/verify.sh` 는 자체 `DUCKDB_DATABASE`(임시 파일)를 export 하며 이 값이 설정 파일보다
우선하므로, 직접 쓰는 데이터베이스는 검증 실행에서 건드려지지 않습니다.

The client is run as `duckdb -bail -noheader -list -nullvalue ''`. `-bail` stops at the
first error like `psql`'s `ON_ERROR_STOP`; without it DuckDB runs the statements after a
failed one (it still exits non-zero at the end — measured on v1.5.6). `-nullvalue ''` prints
`NULL` as an empty field, as `psql` does; without it a one-row NULL result is counted as a
data row by `bin/run.sh`, and three queries (q23_1, q32, q92 on the fixture) report 1 row
where PostgreSQL reports 0.

클라이언트는 `duckdb -bail -noheader -list -nullvalue ''` 로 실행합니다. `-bail` 은 `psql` 의
`ON_ERROR_STOP` 처럼 첫 오류에서 중단하며, 없으면 DuckDB 는 실패한 문장 뒤의 문장도
실행합니다(마지막에는 non-zero 로 종료합니다. v1.5.6 에서 측정). `-nullvalue ''` 는 `psql`
처럼 `NULL` 을 빈 필드로 출력합니다. 없으면 NULL 한 행짜리 결과를 `bin/run.sh` 가 데이터 행으로
세어, 픽스처에서 세 쿼리(q23_1, q32, q92)가 PostgreSQL 의 0 행 대신 1 행을 보고합니다.

## Schema / 스키마

Derived by `tools/derive-ddl.sh` from the repo's Oracle schema exactly as the PostgreSQL
schema is — `dv_create_time` becomes `time`, nothing else changes. Every type
(`integer`, `char(N)`, `varchar(N)`, `decimal(P,S)`, `date`, `time`) was accepted by DuckDB
v1.5.6 unchanged, so the DuckDB schema differs from the PostgreSQL one only in its header.
Primary keys are declared as in PostgreSQL; DuckDB enforces them, so a load with duplicate
keys fails instead of loading silently.

`tools/derive-ddl.sh` 가 PostgreSQL 스키마와 똑같이 리포의 Oracle 스키마에서 파생합니다.
`dv_create_time` 이 `time` 이 되는 것 외에는 바뀌는 것이 없습니다. 모든 타입(`integer`,
`char(N)`, `varchar(N)`, `decimal(P,S)`, `date`, `time`)을 DuckDB v1.5.6 이 그대로
받아들였으므로, DuckDB 스키마는 PostgreSQL 스키마와 헤더만 다릅니다. 기본키는 PostgreSQL 과
같이 선언하며 DuckDB 가 이를 강제하므로, 키가 중복되면 조용히 적재되지 않고 실패합니다.

## Queries / 쿼리

Derived by `tools/sync-upstream.sh duckdb`: the same upstream (the StarRocks copy of the
standard text), the same PostgreSQL adaptations (date arithmetic, `ORDER BY` alias in q36,
q70, q86 — see [PostgreSQL](postgres.md)), and a DuckDB-only fix **only for a query that
fails on DuckDB**. Each file's header says `identical to engines/postgres` or names exactly
what differs. The script refuses to run if a fix no longer changes its query, or if an
unfixed query stops being identical to the PostgreSQL text.

`tools/sync-upstream.sh duckdb` 가 파생합니다. 같은 상류(표준 원문의 StarRocks 사본), 같은
PostgreSQL 변환(날짜 연산, q36·q70·q86 의 `ORDER BY` 별칭, [PostgreSQL](postgres.md) 참고),
그리고 **DuckDB 에서 실패하는 쿼리에만** DuckDB 전용 수정을 적용합니다. 각 파일 헤더에
`identical to engines/postgres` 또는 정확히 무엇이 다른지가 적혀 있습니다. 수정이 더 이상 쿼리를
바꾸지 않거나, 수정이 없는 쿼리가 PostgreSQL 본문과 달라지면 스크립트가 중단됩니다.

The two DuckDB-only fixes:

DuckDB 전용 수정 두 가지:

| Query | PostgreSQL file | DuckDB file | Why / 이유 |
| --- | --- | --- | --- |
| q77 | `coalesce(returns, 0) returns` | `coalesce(returns, 0) as returns` | `RETURNS` is a keyword in DuckDB, so an output alias needs `AS` (the same query already writes `as returns` elsewhere) / DuckDB 에서 `RETURNS` 는 키워드라 출력 별칭에 `AS` 가 필요(같은 쿼리의 다른 곳이 이미 `as returns` 사용) |
| q90 | `...) at,` | `...) as "at",` | `AT` is a keyword in DuckDB and cannot name a derived table even after `AS`; quoting keeps the name, which is never referenced / DuckDB 에서 `AT` 는 키워드이며 `AS` 뒤에서도 파생 테이블 이름이 될 수 없음. 따옴표로 이름을 유지(참조되지 않음) |

Both rewrites are valid PostgreSQL too. They are not needed for a PostgreSQL parser and
they do not change what the query computes.

두 수정 모두 PostgreSQL 에서도 유효합니다. PostgreSQL 파서에는 필요 없으며 쿼리가 계산하는
내용을 바꾸지 않습니다.

## PostgreSQL-dialect queries on DuckDB / DuckDB 에서의 PostgreSQL 방언 쿼리

The question this engine answers for other work: **which of the 103 files in
`engines/postgres/queries/` run unchanged on DuckDB?**

다른 작업을 위해 이 엔진이 답하는 질문: **`engines/postgres/queries/` 의 103개 파일 중 DuckDB
에서 수정 없이 실행되는 것은?**

**101 of 103 run unchanged. q77 and q90 fail at parse time** and need the one-token fixes
above.

**103개 중 101개가 수정 없이 실행됩니다. q77 과 q90 은 파싱 단계에서 실패**하며 위의 한 토큰
수정이 필요합니다.

Measured 2026-10-09 on DuckDB v1.5.6 (`069cc9f9b5`, macOS 26.7.1, arm64): the 103 PostgreSQL
files, comment header stripped (`strip_comments`), run one by one through
`duckdb -bail -noheader -list -nullvalue ''` against a database loaded by
`bin/load.sh --engine duckdb` from the `tools/make-fixture.py` fixture (default seed and
size). "Runs" means exit status 0; the error shown is the first line DuckDB printed. This
is parse/bind/execute only — no answer was compared with anything.

2026-10-09 에 DuckDB v1.5.6(`069cc9f9b5`, macOS 26.7.1, arm64)에서 측정했습니다. PostgreSQL
파일 103개를 주석 헤더를 제거(`strip_comments`)하고 하나씩 `duckdb -bail -noheader -list
-nullvalue ''` 로 실행했으며, 데이터베이스는 `tools/make-fixture.py` 픽스처(기본 seed·크기)를
`bin/load.sh --engine duckdb` 로 적재한 것입니다. "Runs" 는 종료 상태 0 이고, 오류는 DuckDB 가
처음 출력한 줄입니다. 파싱·바인딩·실행만 확인했으며 정답은 무엇과도 비교하지 않았습니다.

| Result / 결과 | Count | Queries |
| --- | :-: | --- |
| ✅ runs unchanged / 수정 없이 실행 | 101 | all except the two below / 아래 둘을 제외한 전부 |
| ❌ fails / 실패 | 2 | q77, q90 |

??? abstract "All 103 results / 103개 전체 결과"

    | Query | Result / 결과 | First error line / 첫 오류 줄 |
    | --- | --- | --- |
    | q01 | ✅ runs | — |
    | q02 | ✅ runs | — |
    | q03 | ✅ runs | — |
    | q04 | ✅ runs | — |
    | q05 | ✅ runs | — |
    | q06 | ✅ runs | — |
    | q07 | ✅ runs | — |
    | q08 | ✅ runs | — |
    | q09 | ✅ runs | — |
    | q10 | ✅ runs | — |
    | q11 | ✅ runs | — |
    | q12 | ✅ runs | — |
    | q13 | ✅ runs | — |
    | q14_1 | ✅ runs | — |
    | q14_2 | ✅ runs | — |
    | q15 | ✅ runs | — |
    | q16 | ✅ runs | — |
    | q17 | ✅ runs | — |
    | q18 | ✅ runs | — |
    | q19 | ✅ runs | — |
    | q20 | ✅ runs | — |
    | q21 | ✅ runs | — |
    | q22 | ✅ runs | — |
    | q23_1 | ✅ runs | — |
    | q23_2 | ✅ runs | — |
    | q24_1 | ✅ runs | — |
    | q24_2 | ✅ runs | — |
    | q25 | ✅ runs | — |
    | q26 | ✅ runs | — |
    | q27 | ✅ runs | — |
    | q28 | ✅ runs | — |
    | q29 | ✅ runs | — |
    | q30 | ✅ runs | — |
    | q31 | ✅ runs | — |
    | q32 | ✅ runs | — |
    | q33 | ✅ runs | — |
    | q34 | ✅ runs | — |
    | q35 | ✅ runs | — |
    | q36 | ✅ runs | — |
    | q37 | ✅ runs | — |
    | q38 | ✅ runs | — |
    | q39_1 | ✅ runs | — |
    | q39_2 | ✅ runs | — |
    | q40 | ✅ runs | — |
    | q41 | ✅ runs | — |
    | q42 | ✅ runs | — |
    | q43 | ✅ runs | — |
    | q44 | ✅ runs | — |
    | q45 | ✅ runs | — |
    | q46 | ✅ runs | — |
    | q47 | ✅ runs | — |
    | q48 | ✅ runs | — |
    | q49 | ✅ runs | — |
    | q50 | ✅ runs | — |
    | q51 | ✅ runs | — |
    | q52 | ✅ runs | — |
    | q53 | ✅ runs | — |
    | q54 | ✅ runs | — |
    | q55 | ✅ runs | — |
    | q56 | ✅ runs | — |
    | q57 | ✅ runs | — |
    | q58 | ✅ runs | — |
    | q59 | ✅ runs | — |
    | q60 | ✅ runs | — |
    | q61 | ✅ runs | — |
    | q62 | ✅ runs | — |
    | q63 | ✅ runs | — |
    | q64 | ✅ runs | — |
    | q65 | ✅ runs | — |
    | q66 | ✅ runs | — |
    | q67 | ✅ runs | — |
    | q68 | ✅ runs | — |
    | q69 | ✅ runs | — |
    | q70 | ✅ runs | — |
    | q71 | ✅ runs | — |
    | q72 | ✅ runs | — |
    | q73 | ✅ runs | — |
    | q74 | ✅ runs | — |
    | q75 | ✅ runs | — |
    | q76 | ✅ runs | — |
    | q77 | ❌ fails | `Parser Error: syntax error at or near "returns"` |
    | q78 | ✅ runs | — |
    | q79 | ✅ runs | — |
    | q80 | ✅ runs | — |
    | q81 | ✅ runs | — |
    | q82 | ✅ runs | — |
    | q83 | ✅ runs | — |
    | q84 | ✅ runs | — |
    | q85 | ✅ runs | — |
    | q86 | ✅ runs | — |
    | q87 | ✅ runs | — |
    | q88 | ✅ runs | — |
    | q89 | ✅ runs | — |
    | q90 | ❌ fails | `Parser Error: syntax error at or near "at"` |
    | q91 | ✅ runs | — |
    | q92 | ✅ runs | — |
    | q93 | ✅ runs | — |
    | q94 | ✅ runs | — |
    | q95 | ✅ runs | — |
    | q96 | ✅ runs | — |
    | q97 | ✅ runs | — |
    | q98 | ✅ runs | — |
    | q99 | ✅ runs | — |

Re-run it with the loop below after loading a database (set `DUCKDB_DATABASE` first); a
different DuckDB version can give a different table, and then this section is stale.

데이터베이스를 적재한 뒤 아래 반복문으로 다시 실행할 수 있습니다(먼저 `DUCKDB_DATABASE` 설정).
DuckDB 버전이 다르면 표가 달라질 수 있으며, 그 경우 이 절은 낡은 것입니다.

```bash
for f in engines/postgres/queries/*.sql; do
  if grep -v '^[[:space:]]*--' "$f" | duckdb -bail -noheader -list "$DUCKDB_DATABASE" >/dev/null 2>/tmp/err; then
    echo "$(basename "$f") runs"
  else
    echo "$(basename "$f") FAILS: $(head -1 /tmp/err)"
  fi
done
```

## Loading / 적재

`COPY <table> FROM '<file>' (FORMAT csv, DELIMITER '|', HEADER false, NULL '', AUTO_DETECT false)`,
once per `.dat` file (so parallel dsdgen chunks work).

dsdgen ends every line with a trailing `|`. PostgreSQL's `COPY` reads that as an extra empty
column, so its loader strips it with `sed`. DuckDB's `COPY` into an existing table accepted
the files as written — measured on v1.5.6 with the fixture: the `call_center` column values were
checked by eye and the row counts of all 24 tables matched — so `load.sh` does not strip anything. The check that makes this safe: after
each table the loader compares the row count in the database with the number of lines in
the `.dat` files and fails on a mismatch. `AUTO_DETECT` is off so the CSV sniffer cannot
guess differently for a small table; the table definition decides the types.

dsdgen 은 각 줄 끝에 `|` 를 붙입니다. PostgreSQL 의 `COPY` 는 이를 추가 빈 컬럼으로 읽으므로 그
로더는 `sed` 로 제거합니다. DuckDB 의 기존 테이블로의 `COPY` 는 파일을 그대로 받아들였고(v1.5.6,
픽스처로 측정. `call_center` 컬럼 값을 눈으로 확인했고 24개 테이블의 행 수가 모두 일치했습니다), 그래서 `load.sh` 는 아무것도 제거하지 않습니다.
이를 안전하게 하는 검사: 테이블마다 데이터베이스의 행 수를 `.dat` 파일의 줄 수와 비교하고
불일치하면 실패합니다. `AUTO_DETECT` 를 꺼서 작은 테이블에서 CSV sniffer 가 다르게 추측하지
못하게 하고, 타입은 테이블 정의가 정합니다.

The loader ends with `CHECKPOINT` so the database file is complete without its write-ahead
log. It runs no `ANALYZE`.

로더는 `CHECKPOINT` 로 끝나므로 데이터베이스 파일이 write-ahead log 없이도 완전합니다.
`ANALYZE` 는 실행하지 않습니다.

!!! note "Not measured / 측정하지 않음"

    Large scale factors. The fixture is small (12,000 rows in the biggest fact table, 86,400 in `time_dim`); the trailing-delimiter
    behaviour, load time, memory use and the cost of enforced primary keys have not been
    checked on dsdgen output at SF 1 or above.

    큰 스케일 팩터. 픽스처는 작고(가장 큰 팩트 테이블 12,000 행, `time_dim` 86,400 행), 끝 구분자 동작, 적재 시간, 메모리 사용량,
    강제되는 기본키의 비용은 SF 1 이상의 dsdgen 출력으로 확인하지 않았습니다.
