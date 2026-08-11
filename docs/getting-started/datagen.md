# Data generation / 데이터 생성

TPC-DS data comes from `dsdgen`, part of the TPC-DS toolkit.

TPC-DS 데이터는 TPC-DS 툴킷의 일부인 `dsdgen` 이 생성합니다.

!!! licence "Licensing / 라이선스"

    The toolkit — `dsdgen`, `dsqgen`, the query templates and the answer sets — is TPC
    copyrighted material distributed under the **TPC End User Licensing Agreement**, not
    an open-source licence. **It is never vendored in this repository.** You obtain it
    yourself, and it lands in the git-ignored `.toolkit/`.

    툴킷(`dsdgen`, `dsqgen`, 쿼리 템플릿, 정답 세트)은 오픈소스 라이선스가 아닌 **TPC
    End User Licensing Agreement** 로 배포되는 TPC 저작물입니다. **이 저장소에 포함하지
    않습니다.** 직접 받으시면 git 에서 제외되는 `.toolkit/` 에 저장됩니다.

## Getting the toolkit / 툴킷 확보

```bash
datagen/fetch-toolkit.sh --community        # clone + build the community fork
datagen/fetch-toolkit.sh --from ~/tpcds-kit # build from a checkout you already have
datagen/fetch-toolkit.sh --check            # report whether a built dsdgen exists
```

Two routes:

두 가지 방법:

=== "Official / 공식"

    <https://www.tpc.org/tpcds/> → *Download TPC-DS Tools*. Accept the EULA, unzip, then:

    EULA 에 동의하고 압축을 푼 뒤 실행하십시오.

    ```bash
    datagen/fetch-toolkit.sh --from /path/to/unzipped/toolkit
    ```

=== "Community / 커뮤니티"

    [`gregrahn/tpcds-kit`](https://github.com/gregrahn/tpcds-kit) — a widely used fork
    carrying patches that let the toolkit build on modern Linux and macOS.

    최신 Linux/macOS 에서 빌드되도록 패치한 널리 쓰이는 포크입니다.

    ```bash
    datagen/fetch-toolkit.sh --community
    ```

    !!! warning "Warning / 주의"

        That repository ships `EULA.txt` and **no** open-source licence. The TPC terms
        still govern what you download. The script prompts before fetching.

        해당 리포지토리에는 `EULA.txt` 만 있고 오픈소스 라이선스가 **없습니다**.
        내려받는 자산에도 TPC 조건이 적용됩니다. 스크립트가 받기 전에 확인을 요청합니다.

The build needs `make` and a C compiler. On macOS that means the Xcode command line
tools; on Debian or Ubuntu, `build-essential`.

빌드에는 `make` 와 C 컴파일러가 필요합니다. macOS 는 Xcode 명령줄 도구,
Debian·Ubuntu 는 `build-essential` 입니다.

## Generating the data / 데이터 생성

```bash
datagen/generate.sh --sf 1   --out ~/tpcds/sf1
datagen/generate.sh --sf 100 --out /data/tpcds/sf100 --parallel 8
datagen/generate.sh --sf 100 --out /data/tpcds/sf100 --parallel 8 --tables store_sales
```

| Flag | Meaning / 의미 |
|:---|:---|
| `--sf <n>` | scale factor in GB, required / 스케일 팩터(GB), 필수 |
| `--out <dir>` | output directory for the `.dat` files, required / `.dat` 출력 디렉터리, 필수 |
| `--parallel <n>` | number of `dsdgen` child processes, default 1 / 자식 프로세스 수 |
| `--tables <spec>` | comma-separated table names, default all / 콤마 구분 테이블명 |
| `--force` | overwrite a non-empty output directory / 비어 있지 않은 디렉터리 덮어쓰기 |

### Parallel output / 병렬 출력

With `--parallel N`, `dsdgen` writes chunked files named
`<table>_<child>_<parallel>.dat` — for example `store_sales_1_8.dat` through
`store_sales_8_8.dat`. The loaders pick those chunks up automatically.

`--parallel N` 을 쓰면 `dsdgen` 이 `<table>_<child>_<parallel>.dat` 형식의 청크 파일을
생성합니다. 예를 들어 `store_sales_1_8.dat` ~ `store_sales_8_8.dat` 입니다. 로더가 해당
청크를 자동으로 인식합니다.

!!! note "Note / 참고"

    Chunk files are matched strictly as `_<digits>_<digits>.dat`, not with a loose
    `<table>_*.dat` glob. A loose glob would also match other TPC-DS tables that share a
    prefix — `customer_address.dat` for `customer`, `store_sales.dat` for `store` — and
    concatenate them into the wrong table.

    청크 파일은 느슨한 `<table>_*.dat` 글롭이 아니라 `_<숫자>_<숫자>.dat` 로 엄격히
    매칭합니다. 느슨한 글롭은 접두어를 공유하는 다른 TPC-DS 테이블(`customer` 에
    `customer_address.dat`, `store` 에 `store_sales.dat`)도 매칭해 잘못된 테이블에
    이어붙이게 됩니다.

## The output format / 출력 형식

`dsdgen` writes pipe-delimited rows **with a trailing delimiter on every line**:

`dsdgen` 은 **각 줄 끝에도 구분자가 붙은** 파이프 구분 행을 출력합니다.

```text
1|AAAAAAAABAAAAAAA|Package was damaged|
2|AAAAAAAACAAAAAAA|Stopped working|
```

Every loader here strips that trailing `|` on the way in, because each engine would
otherwise read it as an extra empty column and reject the row. The generated files are
never modified in place.

여기의 모든 로더가 적재 중에 마지막 `|` 를 제거합니다. 그렇지 않으면 각 엔진이 이를 추가
빈 컬럼으로 읽고 행을 거부합니다. 생성된 파일은 원본 그대로 유지됩니다.

Fields are written in the TPC-DS specification column order. That matters for StarRocks,
whose `CREATE TABLE` reorders all six fact tables, so its loader maps fields by name
instead of by position.

필드는 TPC-DS 규격 컬럼 순서로 기록됩니다. 이는 StarRocks 에서 중요합니다. StarRocks 의
`CREATE TABLE` 이 6개 팩트 테이블 전부를 재배열하므로, 해당 로더는 위치 대신 이름으로
필드를 매핑합니다.

## No data generation needed / 데이터 생성이 필요 없는 경우

To check that the SQL runs, skip all of the above and use the synthetic fixture:

SQL 실행 여부만 확인하려면 위 과정을 모두 생략하고 합성 픽스처를 사용하십시오.

```bash
tools/verify.sh --all
```

`tools/make-fixture.py` writes ~140,000 rows across all 24 tables in the same format.
It is our own synthetic data, not TPC-DS data, so no EULA acceptance is involved — and it
produces no meaningful answers. See [Verification](../verification/index.md).

`tools/make-fixture.py` 가 동일한 형식으로 24개 테이블에 약 140,000 행을 생성합니다.
TPC-DS 데이터가 아닌 자체 합성 데이터이므로 EULA 동의가 필요하지 않으며, 의미 있는 정답을
만들지도 않습니다. [검증](../verification/index.md) 참고.
