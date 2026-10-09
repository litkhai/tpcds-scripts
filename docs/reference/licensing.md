# Licensing / 라이선스

This page is a summary. The authoritative record is
[`NOTICE.md`](https://github.com/litkhai/tpcds-scripts/blob/master/NOTICE.md) in the
repository, and each SQL file's own header.

이 페이지는 요약입니다. 정본은 저장소의
[`NOTICE.md`](https://github.com/litkhai/tpcds-scripts/blob/master/NOTICE.md) 와 각 SQL
파일의 헤더입니다.

## TPC-DS is not open source / TPC-DS 는 오픈소스가 아닙니다

TPC-DS is a benchmark specification owned by the
[Transaction Processing Performance Council](https://www.tpc.org/). The specification,
the query templates, the data generator (`dsdgen`), the query generator (`dsqgen`) and
the answer sets are TPC copyrighted material distributed under the **TPC End User
Licensing Agreement**. They are not released under an open-source licence, and the EULA —
not this repository — governs your use of them.

TPC-DS 는 [TPC](https://www.tpc.org/) 가 소유한 벤치마크 규격입니다. 규격, 쿼리 템플릿,
데이터 생성기(`dsdgen`), 쿼리 생성기(`dsqgen`), 정답 세트는 모두 **TPC End User Licensing
Agreement** 로 배포되는 TPC 저작물입니다. 오픈소스 라이선스로 공개된 것이 아니며, 이들의
사용은 이 저장소가 아니라 EULA 가 규율합니다.

`TPC`, `TPC-DS`, `TPC-H` and `QphDS` are trademarks of the TPC.

`TPC`, `TPC-DS`, `TPC-H`, `QphDS` 는 TPC 의 상표입니다.

### What this repository does not contain / 이 저장소에 없는 것

| Not included / 미포함 | Why / 이유 |
|:---|:---|
| `dsdgen`, `dsqgen` source or binaries | TPC EULA material. `datagen/fetch-toolkit.sh` helps you obtain it; it lands in the git-ignored `.toolkit/`. |
| Official query templates | TPC EULA material |
| Official answer sets | TPC EULA material — which is why verification cannot check answers / 검증이 정답을 확인할 수 없는 이유입니다 |
| The specification PDF | TPC EULA material |

## Results here are not TPC-DS results / 여기서 측정한 값은 TPC-DS 결과가 아닙니다

!!! warning "Warning / 주의"

    The workloads in this repository are **derived from** the TPC-DS benchmark. They are
    **not** an audited, TPC-compliant implementation. No result produced with these
    scripts is a TPC Benchmark™ result, none may be described as a TPC-DS result, and
    none is comparable to any officially published TPC-DS result.

    이 저장소의 워크로드는 TPC-DS 벤치마크에서 **파생된** 것입니다. 공인·감사된 TPC 규격
    준수 구현이 **아닙니다**. 이 스크립트로 얻은 어떤 결과도 TPC Benchmark™ 결과가 아니며,
    TPC-DS 결과로 표현할 수 없고, 공식 공표된 TPC-DS 결과와 비교할 수 없습니다.

Each of the following alone disqualifies a run:

다음 각 항목만으로도 자격이 상실됩니다.

- **No audit.** A compliant result requires an independent auditor and a Full Disclosure
  Report. / **감사 없음.**
- **Fixed substitution parameters** instead of values generated per stream by `dsqgen`.
  / **고정 치환 파라미터.**
- **No throughput, data maintenance or persistence tests** — only the single-stream power
  run is scripted, and `QphDS@SF` requires all of them. / **처리량·유지보수·영속성 테스트
  없음.**
- **Dialect adaptations** per engine. / **엔진별 방언 변환.**
- **Optional auxiliary structures** in `engines/*/tuning/`. / **선택적 보조 구조.**

Call your numbers **"TPC-DS derived"**, and state the scale factor, engine version,
hardware and configuration alongside them. Read the
[TPC Fair Use policies](https://www.tpc.org/information/about/fairuse.asp) before
publishing comparative figures. See also [Methodology](methodology.md).

측정값은 **"TPC-DS 파생"** 으로 표기하고 스케일 팩터·엔진 버전·하드웨어·설정을 함께
명시하십시오. 비교 수치를 공개하기 전에
[TPC Fair Use 정책](https://www.tpc.org/information/about/fairuse.asp) 을 확인하십시오.
[방법론](methodology.md) 도 참고하십시오.

## Where each engine's SQL came from / 엔진별 SQL 출처

Every SQL file carries a header naming its upstream repository, the pinned commit, the
upstream path, the upstream licence and the adaptation applied. The file headers are
authoritative; this table summarises.

모든 SQL 파일 헤더에 상류 리포지토리·핀 고정 커밋·경로·라이선스·적용된 변환이 기재되어
있습니다. 파일 헤더가 정본이며 아래 표는 요약입니다.

| Engine / 엔진 | Source / 출처 | Upstream licence | Adaptation / 변환 |
|:---|:---|:---|:---|
| **Oracle** | Repo-native — present since this repository's first commits / 리포 고유 자산, 최초 커밋부터 존재 | — | Oracle dialect: `rownum <= 100`, `to_date(...) + N` |
| **PostgreSQL** | Derived from the StarRocks copy of the standard TPC-DS query text / StarRocks 사본의 표준 원문에서 파생 | Apache-2.0 | `date_add(d, n)` → `(d ± n)`; `ORDER BY` alias `lochierarchy` expanded (q36/q70/q86). Schema derived from the Oracle schema with `dv_create_time date` → `time`. |
| **Vertica** | Same base as PostgreSQL / PostgreSQL 과 동일 베이스 | Apache-2.0 | Same as PostgreSQL / PostgreSQL 과 동일 |
| **DuckDB** | The PostgreSQL query set / PostgreSQL 쿼리 세트 | Apache-2.0 | Same as PostgreSQL, plus q77 `coalesce(returns, 0) as returns` and q90 `as "at"` / PostgreSQL 과 동일, q77·q90 추가 수정 |
| **ClickHouse** | [`ClickHouse/ClickHouse`](https://github.com/ClickHouse/ClickHouse) `tests/benchmarks/tpc-ds/` | Apache-2.0 | Verbatim; q14/23/24/39 split into `_1`/`_2` |
| **StarRocks** | [`StarRocks/starrocks`](https://github.com/StarRocks/starrocks) `fe/fe-core/src/test/resources/sql/tpcds/` | Apache-2.0 | Verbatim, except the unloadable `call_center` RANGE partition, removed as a documented adaptation |

Pinned commits live at the top of `tools/sync-upstream.sh`. Re-running it reproduces every
imported and derived file, so provenance is checkable rather than resting on this page.

핀 고정 커밋은 `tools/sync-upstream.sh` 상단에 있습니다. 재실행하면 임포트·파생 파일이 모두
재생성되므로 출처는 이 페이지에 의존하지 않고 검증 가능합니다.

### On the Apache-2.0 sources / Apache-2.0 소스에 대하여

ClickHouse, StarRocks and Trino publish TPC-DS derived SQL in Apache-2.0 licensed
repositories, and redistributing derived query text this way is established practice
across database projects. Be clear about what that does and does not settle: the
Apache-2.0 grant covers each project's own contribution, and it does not and cannot
extinguish TPC's underlying rights in the benchmark. This repository follows the same
practice, attributes every source explicitly, and carries the non-comparability
disclaimer above. If your use is commercial, or you intend to publish comparative
figures, take your own legal advice.

ClickHouse, StarRocks, Trino 는 Apache-2.0 리포지토리에 TPC-DS 파생 SQL 을 공개하며, 이런
방식의 재배포는 데이터베이스 프로젝트들 사이에서 확립된 관행입니다. 다만 이것이 해결하는
범위를 명확히 구분하십시오. Apache-2.0 허여는 각 프로젝트 자신의 기여물에 적용되며, 벤치마크에
대한 TPC 의 기저 권리를 소멸시키지 않고 소멸시킬 수도 없습니다. 이 저장소는 동일한 관행을
따르고 모든 출처를 명시하며 위의 비교 불가 고지를 포함합니다. 상업적 사용이나 비교 수치
공개를 계획한다면 별도의 법률 자문을 받으십시오.

### Sources deliberately rejected / 의도적으로 배제한 소스

| Source | Reason / 이유 |
|:---|:---|
| [`gregrahn/tpcds-kit`](https://github.com/gregrahn/tpcds-kit) | Ships `EULA.txt` and **no** open-source licence. Referenced by `datagen/fetch-toolkit.sh` as a download target, never vendored. / `EULA.txt` 만 있고 오픈소스 라이선스가 **없음**. 다운로드 대상으로만 참조하며 포함하지 않음. |
| `duckdb/duckdb` `extension/tpcds/` | Repository root is MIT, but this subtree vendors the TPC `dsdgen` C source; MIT at the root does not clear the TPC material inside it. / 루트는 MIT 이지만 하위 트리가 TPC `dsdgen` C 소스를 포함하며, 루트의 MIT 가 내부 TPC 자산을 해소하지 않음. |
| Various `tpcds-vertica` repositories | No licence, or `NOASSERTION`. Vertica queries are therefore derived here from the Apache-2.0 base instead. / 라이선스 없음 또는 `NOASSERTION`. 따라서 Vertica 쿼리는 Apache-2.0 베이스에서 파생. |

## This repository's own code / 이 저장소 고유 코드

The scripts written for this project — everything under `bin/`, `tools/`, `datagen/`,
`docker/`, `config/`, the engine `load/` and `tuning/` scripts, and this documentation —
are licensed under **Apache-2.0**.

이 프로젝트를 위해 작성된 스크립트, 즉 `bin/`, `tools/`, `datagen/`, `docker/`, `config/`,
엔진별 `load/`·`tuning/` 스크립트 및 이 문서는 **Apache-2.0** 라이선스를 따릅니다.

That licence covers the orchestration this project contributes. It does not, and could
not, relicense the TPC-DS derived SQL described above.

이 라이선스는 프로젝트가 기여한 오케스트레이션 부분에 적용됩니다. 위에서 설명한 TPC-DS 파생
SQL 을 재라이선스하지 않으며, 그렇게 할 수도 없습니다.

## Licence texts / 라이선스 전문

- Apache License 2.0 — <https://www.apache.org/licenses/LICENSE-2.0>
- TPC End User Licensing Agreement — included with the toolkit download from
  <https://www.tpc.org/tpcds/> / 툴킷 다운로드에 포함
- TPC Fair Use policies — <https://www.tpc.org/information/about/fairuse.asp>
