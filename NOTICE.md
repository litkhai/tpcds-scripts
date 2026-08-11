# NOTICE — Provenance and licensing / 출처 및 라이선스

This file records where every piece of SQL in this repository came from and what
terms apply to it. Read it before publishing anything measured with these scripts.

이 파일은 리포지토리에 담긴 모든 SQL 의 출처와 적용 조건을 기록합니다. 이
스크립트로 측정한 결과를 공개하기 전에 반드시 읽어보십시오.

---

## 1. TPC-DS is not open source / TPC-DS 는 오픈소스가 아닙니다

TPC-DS is a benchmark specification owned by the
[Transaction Processing Performance Council (TPC)](https://www.tpc.org/).
The specification, the query templates, the data generator (`dsdgen`), the query
generator (`dsqgen`) and the answer sets are TPC copyrighted material distributed
under the **TPC End User Licensing Agreement (EULA)**. They are not released under
an open-source licence, and the EULA — not this repository — governs your use of
them.

TPC-DS 는 [TPC](https://www.tpc.org/) 가 소유한 벤치마크 규격입니다. 규격, 쿼리
템플릿, 데이터 생성기(`dsdgen`), 쿼리 생성기(`dsqgen`), 정답 세트는 모두 **TPC End
User Licensing Agreement (EULA)** 로 배포되는 TPC 저작물입니다. 오픈소스
라이선스로 공개된 것이 아니며, 이들의 사용은 이 리포지토리가 아니라 EULA 가
규율합니다.

`TPC`, `TPC-DS`, `TPC-H` and `QphDS` are trademarks of the TPC.

`TPC`, `TPC-DS`, `TPC-H`, `QphDS` 는 TPC 의 상표입니다.

### What this repository therefore does NOT contain / 이 리포지토리에 없는 것

| Not included / 미포함 | Why / 이유 |
| --- | --- |
| `dsdgen`, `dsqgen` source or binaries | TPC EULA material. `datagen/fetch-toolkit.sh` helps you obtain it yourself; it lands in the git-ignored `.toolkit/`. |
| Official TPC-DS query templates (`query_templates/`) | TPC EULA material. |
| Official answer sets (`answer_sets/`) | TPC EULA material. |
| The TPC-DS specification PDF | TPC EULA material. |

`datagen/fetch-toolkit.sh` 는 툴킷을 직접 받도록 돕고, 받은 결과물은 git 에서 제외되는
`.toolkit/` 에 저장됩니다.

---

## 2. Results measured here are not TPC-DS results / 여기서 측정한 값은 TPC-DS 결과가 아닙니다

> The workloads in this repository are **derived from** the TPC-DS benchmark. They
> are **not** an audited, TPC-compliant TPC-DS implementation. No result produced
> with these scripts is a TPC Benchmark™ result, none may be described as a
> TPC-DS result, and none is comparable to any officially published TPC-DS result.
>
> 이 리포지토리의 워크로드는 TPC-DS 벤치마크에서 **파생된** 것입니다. 공인·감사된
> TPC 규격 준수 구현이 **아닙니다**. 이 스크립트로 얻은 어떤 결과도 TPC Benchmark™
> 결과가 아니며, TPC-DS 결과로 표현할 수 없고, 공식 공표된 TPC-DS 결과와 비교할 수
> 없습니다.

Concretely, this repository departs from the TPC-DS specification in ways that each
alone disqualify a run from being a TPC-DS result:

구체적으로, 다음 각 항목만으로도 TPC-DS 결과 자격이 상실됩니다.

- **No audit.** A compliant result requires an independent auditor and a Full
  Disclosure Report. / **감사 없음.** 규격 준수 결과에는 독립 감사인과 Full
  Disclosure Report 가 필요합니다.
- **Fixed substitution parameters.** The queries carry hardcoded qualification
  values instead of values generated per run by `dsqgen`. / **고정 치환 파라미터.**
  실행마다 `dsqgen` 이 생성한 값이 아니라 고정된 qualification 값을 사용합니다.
- **No throughput, refresh or persistence tests.** Only the single-stream power run
  is scripted; the `QphDS@SF` metric requires all of them. / **처리량·갱신·영속성
  테스트 없음.** 단일 스트림 power run 만 스크립트화되어 있으며, `QphDS@SF` 지표는
  전체를 요구합니다.
- **Dialect adaptations.** Queries were modified per engine — see §3 and each
  file's header. / **방언 변환.** 엔진별로 쿼리를 수정했습니다. §3 및 각 파일 헤더 참고.
- **Optional indexes.** `engines/*/tuning/` offers auxiliary structures the TPC-DS
  rules constrain. / **선택적 인덱스.** `engines/*/tuning/` 은 TPC-DS 규칙이 제한하는
  보조 구조를 제공합니다.

Describe your numbers as "TPC-DS derived" and state the scale factor, engine
version, hardware and configuration alongside them.

측정값은 "TPC-DS 파생(TPC-DS derived)" 으로 표기하고, 스케일 팩터·엔진 버전·하드웨어·
설정을 함께 명시하십시오.

---

## 3. Per-engine provenance / 엔진별 출처

Every SQL file carries a header naming its upstream repository, the pinned commit,
the upstream path, the upstream licence and the adaptation applied. The table below
summarises; the file headers are authoritative.

모든 SQL 파일 헤더에 상류 리포지토리, 핀 고정 커밋, 상류 경로, 상류 라이선스,
적용된 변환이 기재되어 있습니다. 아래 표는 요약이며, 파일 헤더가 정본입니다.

| Engine / 엔진 | Queries + schema from / 쿼리·스키마 출처 | Upstream licence | Adaptation / 변환 |
| --- | --- | --- | --- |
| **Oracle** | Repo-native. Present since this repository's first commits; predates the multi-engine restructure. / 리포 고유 자산. 최초 커밋부터 존재하며 다중 엔진 재구성보다 앞섭니다. | — (see §4) | Oracle dialect throughout: `rownum <= 100` for row limiting, `to_date(...) + N` for date arithmetic. |
| **PostgreSQL** | Derived from the StarRocks copy of the standard TPC-DS query text. / StarRocks 사본의 표준 TPC-DS 쿼리 원문에서 파생. | Apache-2.0 | `date_add(d, n)` → `(d + n)` / `(d - n)`; `ORDER BY` alias `lochierarchy` expanded to its defining expression (q36/q70/q86). Schema derived from the repo's Oracle schema with `dv_create_time date` → `time`. |
| **Vertica** | Same base as PostgreSQL. / PostgreSQL 과 동일 베이스. | Apache-2.0 | Same as PostgreSQL. Physical design guidance only in `tuning/` — no hand-written projections. |
| **ClickHouse** | [`ClickHouse/ClickHouse`](https://github.com/ClickHouse/ClickHouse) `tests/benchmarks/tpc-ds/` | Apache-2.0 | Imported verbatim. Files for q14/23/24/39 hold both formulations upstream and were split into `_1`/`_2`. |
| **StarRocks** | [`StarRocks/starrocks`](https://github.com/StarRocks/starrocks) `fe/fe-core/src/test/resources/sql/tpcds/` | Apache-2.0 | Imported verbatim. Per-table DDL concatenated into one schema script. |

Pinned upstream commits live at the top of `tools/sync-upstream.sh`. Re-running that
script reproduces every imported and derived file, so provenance stays checkable
rather than resting on this document.

핀 고정된 상류 커밋은 `tools/sync-upstream.sh` 상단에 있습니다. 이 스크립트를 다시
실행하면 임포트·파생 파일이 모두 재생성되므로, 출처는 이 문서에 의존하지 않고 검증
가능한 상태로 유지됩니다.

### A note on the Apache-2.0 sources / Apache-2.0 소스에 대한 참고

ClickHouse, StarRocks and Trino publish TPC-DS derived SQL in Apache-2.0 licensed
repositories, and redistributing TPC-DS derived query text this way is established
practice across database projects. Be aware of what that does and does not settle:
the Apache-2.0 grant covers each project's own contribution, and it does not and
cannot extinguish TPC's underlying rights in the benchmark. This repository relies
on the same practice, attributes each source explicitly, and carries the
non-comparability disclaimer in §2. If your use is commercial or you intend to
publish comparative figures, take your own legal advice.

ClickHouse, StarRocks, Trino 는 Apache-2.0 리포지토리에 TPC-DS 파생 SQL 을 공개하며,
이런 방식의 재배포는 데이터베이스 프로젝트들 사이에서 확립된 관행입니다. 다만 이것이
해결하는 범위와 그렇지 않은 범위를 구분하십시오. Apache-2.0 허여는 각 프로젝트 자신의
기여물에 적용되며, 벤치마크에 대한 TPC 의 기저 권리를 소멸시키지 않고 소멸시킬 수도
없습니다. 이 리포지토리는 동일한 관행을 따르고 각 출처를 명시하며 §2 의 비교 불가
고지를 포함합니다. 상업적 사용이나 비교 수치 공개를 계획한다면 별도의 법률 자문을
받으십시오.

### Sources deliberately not used / 의도적으로 사용하지 않은 소스

| Source | Reason / 이유 |
| --- | --- |
| [`gregrahn/tpcds-kit`](https://github.com/gregrahn/tpcds-kit) | Ships `EULA.txt` and **no** open-source licence. Referenced by `datagen/fetch-toolkit.sh` as a download target, never vendored. / `EULA.txt` 만 있고 오픈소스 라이선스가 **없음**. `datagen/fetch-toolkit.sh` 의 다운로드 대상으로만 참조하며 vendoring 하지 않음. |
| `duckdb/duckdb` `extension/tpcds/` | Repository root is MIT, but this subtree vendors the TPC `dsdgen` C source; MIT at the root does not clear the TPC material inside it. / 루트는 MIT 이지만 이 하위 트리는 TPC `dsdgen` C 소스를 포함하며, 루트의 MIT 가 내부 TPC 자산을 해소하지 않음. |
| Various `tpcds-vertica` GitHub repositories | No licence, or `NOASSERTION`. Vertica queries are therefore derived here from the Apache-2.0 base instead. / 라이선스 없음 또는 `NOASSERTION`. 따라서 Vertica 쿼리는 Apache-2.0 베이스에서 파생함. |

---

## 4. This repository's own code / 이 리포지토리 고유 코드

The scripts written for this project — everything under `bin/`, `tools/`,
`datagen/`, `docker/`, `config/`, the engine `load/` and `tuning/` scripts, and the
documentation — are licensed under **Apache-2.0**. See [`LICENSE`](LICENSE).

이 프로젝트를 위해 작성된 스크립트, 즉 `bin/`, `tools/`, `datagen/`, `docker/`,
`config/`, 엔진별 `load/`·`tuning/` 스크립트 및 문서는 **Apache-2.0** 라이선스를
따릅니다. [`LICENSE`](LICENSE) 참고.

That licence covers the orchestration this project contributes. It does not, and
could not, relicense the TPC-DS derived SQL described in §1–§3.

이 라이선스는 프로젝트가 기여한 오케스트레이션 부분에 적용됩니다. §1~§3 에서 설명한
TPC-DS 파생 SQL 을 재라이선스하지 않으며, 그렇게 할 수도 없습니다.

---

## 5. Third-party licence texts / 제3자 라이선스 전문

- Apache License 2.0 — <https://www.apache.org/licenses/LICENSE-2.0>
- TPC End User Licensing Agreement — included with the toolkit download from
  <https://www.tpc.org/tpcds/> / 툴킷 다운로드에 포함되어 있습니다.
- TPC Fair Use policies — <https://www.tpc.org/information/about/fairuse.asp>
