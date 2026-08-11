---
title: Engines
layout: default
nav_order: 3
has_children: true
---

# Engines / 엔진

Per-engine setup, dialect notes and known caveats.

엔진별 설정, 방언 특징, 알려진 주의 사항.

| Engine / 엔진 | Queries | Loader / 로더 | Docker | Statistics step / 통계 단계 |
| --- | :-: | --- | :-: | --- |
| [Oracle](oracle.md) | 103 | SQL\*Loader | ✖ | `DBMS_STATS` — required / 필수 |
| [PostgreSQL](postgres.md) | 103 | `COPY` | ✅ | `ANALYZE` — automatic in loader / 로더가 자동 실행 |
| [Vertica](vertica.md) | 103 | `COPY ... DIRECT` | ✅ CE | `ANALYZE_STATISTICS` — automatic / 자동 |
| [ClickHouse](clickhouse.md) | 103 | `INSERT ... FORMAT CSV` | ✅ | none needed / 불필요 |
| [StarRocks](starrocks.md) | 103 | Stream Load | ✅ | `ANALYZE TABLE` — automatic / 자동 |

## Query set origins / 쿼리 세트 출처

| Engine | Source / 출처 | Change / 변경 |
| --- | --- | --- |
| Oracle | Repo-native / 리포 고유 | Oracle dialect: `rownum`, `to_date(...) + N` |
| ClickHouse | `ClickHouse/ClickHouse` (Apache-2.0) | Verbatim; q14/23/24/39 split into `_1`/`_2` |
| StarRocks | `StarRocks/starrocks` (Apache-2.0) | Verbatim |
| PostgreSQL, Vertica | Derived from the StarRocks copy of the standard text | `date_add(d, n)` → `(d ± n)`; `ORDER BY` alias expanded (q36/q70/q86) |

{: .note }
> Oracle uses different substitution parameters from the other four engines, so its
> result rows are not directly comparable even at the same scale factor. See the
> [Oracle guide](oracle.md).
>
> Oracle 은 나머지 네 엔진과 다른 치환 파라미터를 사용하므로 동일 스케일 팩터에서도
> 결과 행을 직접 비교할 수 없습니다. [Oracle 안내](oracle.md) 참고.
