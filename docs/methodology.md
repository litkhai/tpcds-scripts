---
title: Methodology & fair use
layout: default
nav_order: 2
---

# Methodology and fair use / 측정 방법론 및 fair use

## What is measured / 무엇을 측정하는가

`bin/run.sh` measures wall-clock time around each invocation of the engine's own
command-line client. That figure includes connection setup, query planning,
execution, and the transfer of the result rows back to the client.

`bin/run.sh` 는 각 엔진의 CLI 호출을 감싼 실측(wall-clock) 시간을 측정합니다. 이
수치에는 접속 설정, 쿼리 계획, 실행, 결과 행의 클라이언트 전송이 포함됩니다.

That is a deliberate choice: it is what a user actually waits for. It is also why
these numbers are not engine-internal execution times. If you want to separate
planning from execution, or exclude transfer cost, read it from the engine
(`EXPLAIN ANALYZE`, `system.query_log`, `QUERY_PROFILES`) rather than from the CSV.

이는 의도적인 선택입니다. 사용자가 실제로 기다리는 시간이기 때문입니다. 동시에 이
수치가 엔진 내부 실행 시간이 아닌 이유이기도 합니다. 계획과 실행을 분리하거나 전송
비용을 제외하려면 CSV 대신 엔진 쪽 정보(`EXPLAIN ANALYZE`, `system.query_log`,
`QUERY_PROFILES`)를 확인하십시오.

## What is not measured / 측정하지 않는 것

TPC-DS defines its metric `QphDS@SF` over four tests. This repository scripts only
the first.

TPC-DS 는 지표 `QphDS@SF` 를 네 가지 테스트로 정의합니다. 이 저장소는 그중 첫 번째만
스크립트화합니다.

| TPC-DS test / 테스트 | Here / 이 저장소 |
| --- | --- |
| Load test / 적재 테스트 | Timed by `bin/load.sh`, but not to TPC-DS rules / `bin/load.sh` 가 시간을 재지만 TPC-DS 규칙을 따르지 않음 |
| Power test — one query stream / 단일 쿼리 스트림 | ✅ this is what `bin/run.sh` does |
| Throughput test — concurrent streams / 동시 스트림 | ✖ not implemented / 미구현 |
| Data maintenance test / 데이터 유지보수 테스트 | ✖ not implemented / 미구현 |

So there is no `QphDS@SF` here, and there cannot be one without the missing tests
and an independent audit.

따라서 여기에는 `QphDS@SF` 가 없으며, 누락된 테스트와 독립 감사 없이는 존재할 수
없습니다.

## Why results are not comparable to published TPC-DS results / 공표된 TPC-DS 결과와 비교할 수 없는 이유

Each of these alone is disqualifying:

다음 각 항목만으로도 자격이 상실됩니다.

1. **No audit or Full Disclosure Report.** A compliant TPC-DS result requires an
   independent auditor and a published FDR.
   **감사 및 Full Disclosure Report 없음.** 규격 준수 결과에는 독립 감사인과 공개된
   FDR 이 필요합니다.
2. **Fixed substitution parameters.** The queries carry hardcoded qualification
   values. A compliant run generates fresh values per stream with `dsqgen`, which is
   what stops the engine from caching its way to a good number.
   **고정 치환 파라미터.** 쿼리에 qualification 값이 고정되어 있습니다. 규격 준수
   실행은 `dsqgen` 으로 스트림마다 새 값을 생성하며, 이것이 엔진이 캐싱으로 좋은
   수치를 얻는 것을 막습니다.
3. **Dialect adaptations.** Queries were modified per engine. Each file's header
   states exactly what changed.
   **방언 변환.** 엔진별로 쿼리를 수정했습니다. 각 파일 헤더에 변경 내용이 명시되어
   있습니다.
4. **Optional auxiliary structures.** `engines/*/tuning/` offers indexes that the
   TPC-DS rules constrain.
   **선택적 보조 구조.** `engines/*/tuning/` 은 TPC-DS 규칙이 제한하는 인덱스를
   제공합니다.
5. **Missing tests.** See the table above.
   **테스트 누락.** 위 표 참고.

## Reporting your numbers / 수치 보고 방법

Call them **"TPC-DS derived"**, never "TPC-DS". Alongside any figure, state:

**"TPC-DS 파생(TPC-DS derived)"** 으로 표기하고 "TPC-DS" 라고 하지 마십시오. 수치와
함께 다음을 명시하십시오.

- Scale factor / 스케일 팩터
- Engine name and exact version / 엔진 이름과 정확한 버전
- Hardware: CPU model, core count, RAM, storage type / 하드웨어: CPU 모델, 코어 수, RAM, 스토리지 종류
- Cluster shape: node count, whether storage is local or object / 클러스터 구성: 노드 수, 로컬/오브젝트 스토리지 여부
- Non-default configuration / 기본값과 다른 설정
- Whether `tuning/` was applied / `tuning/` 적용 여부
- Iterations, warmup count, and whether you report median or minimum / 반복 횟수, 예열 횟수, 중앙값/최솟값 보고 여부

Read the [TPC Fair Use policies](https://www.tpc.org/information/about/fairuse.asp)
before publishing comparative figures.

비교 수치를 공개하기 전에 [TPC Fair Use 정책](https://www.tpc.org/information/about/fairuse.asp)
을 확인하십시오.

## Getting a meaningful comparison / 의미 있는 비교를 얻으려면

Cross-engine comparison is easy to get wrong. Things that reliably invalidate one:

엔진 간 비교는 쉽게 잘못됩니다. 비교를 무효화하는 대표적인 요인:

- **Statistics not collected.** Without them PostgreSQL, Oracle and Vertica pick
  nested loops for joins that need hash joins, and the result says nothing about the
  engine. `bin/load.sh` runs the statistics step for you; do not skip it.
  **통계 미수집.** 통계가 없으면 PostgreSQL, Oracle, Vertica 는 해시 조인이 필요한
  곳에 중첩 루프를 선택하며, 그 결과는 엔진에 대해 아무것도 말해주지 않습니다.
  `bin/load.sh` 가 통계 단계를 수행하므로 생략하지 마십시오.
- **Cold versus warm cache.** The first run of a query reads from storage; later runs
  may not. Use `--warmup 1 --iterations 3` and report the median, or explicitly drop
  caches between runs and report cold times. Do not mix the two.
  **콜드 캐시 대 웜 캐시.** 첫 실행은 스토리지에서 읽지만 이후 실행은 그렇지 않을 수
  있습니다. `--warmup 1 --iterations 3` 으로 중앙값을 보고하거나, 실행 사이에 캐시를
  명시적으로 비우고 콜드 시간을 보고하십시오. 둘을 섞지 마십시오.
- **Different scale factors.** SF 10 and SF 100 are not proportional; join
  selectivities change.
  **다른 스케일 팩터.** SF 10 과 SF 100 은 비례하지 않으며 조인 선택도가 달라집니다.
- **Containers with shared CPU.** The `docker/` setup is for development and
  correctness checks, not for measurement.
  **CPU 를 공유하는 컨테이너.** `docker/` 구성은 개발과 정합성 확인용이며 측정용이
  아닙니다.
- **Comparing with and without `tuning/`.** Applying indexes on one engine and not
  another measures your configuration, not the engines.
  **`tuning/` 적용 여부가 다른 비교.** 한 엔진에만 인덱스를 적용하면 엔진이 아니라
  설정을 측정하게 됩니다.

## Correctness before speed / 속도보다 정합성

A fast wrong answer is worthless, and this repository cannot check answers for you:
the official TPC-DS answer sets are TPC EULA material and are not included. To
validate results, use `--keep-output` on two engines at the same scale factor and
compare:

빠른 오답은 무의미하며, 이 저장소는 정답을 검증해 줄 수 없습니다. 공식 TPC-DS 정답
세트는 TPC EULA 자산이라 포함되지 않기 때문입니다. 결과를 검증하려면 동일 스케일
팩터에서 두 엔진에 `--keep-output` 을 사용해 비교하십시오.

```bash
bin/run.sh --engine postgres   --sf 1 --keep-output
bin/run.sh --engine clickhouse --sf 1 --keep-output
diff <(sort results/…-postgres-sf1-output/query01.out) \
     <(sort results/…-clickhouse-sf1-output/query01.out)
```

Expect legitimate differences in numeric formatting, decimal scale and the ordering
of rows that the query does not fully order. A difference in the values themselves is
worth investigating.

숫자 형식, 소수 자릿수, 쿼리가 완전히 정렬하지 않는 행의 순서에서는 정상적인 차이가
발생합니다. 값 자체가 다르다면 조사할 필요가 있습니다.
