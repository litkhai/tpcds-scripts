# Schema divergence / 스키마 불일치

Not all five schemas follow the same TPC-DS revision, because three of them come from
different places: Oracle is repo-native, PostgreSQL and Vertica are derived from it, and
ClickHouse and StarRocks are imported verbatim from upstream projects.

다섯 스키마가 모두 같은 TPC-DS 리비전을 따르지는 않습니다. 세 종류가 서로 다른 출처에서
왔기 때문입니다. Oracle 은 리포 고유 자산, PostgreSQL 과 Vertica 는 이를 파생한 것,
ClickHouse 와 StarRocks 는 상류 프로젝트에서 그대로 가져온 것입니다.

```bash
python3 tools/compare-schemas.py
python3 tools/compare-schemas.py --markdown
```

The five schemas do not all follow the same TPC-DS revision, because three come from
different places. This matters concretely: a single fixture cannot load into engines
whose column lists or column order differ, and results are not comparable where a column
means something different.

다섯 스키마가 모두 같은 TPC-DS 리비전을 따르지는 않습니다. 세 종류가 서로 다른 출처에서
왔기 때문입니다. 이는 구체적인 문제입니다. 컬럼 목록이나 순서가 다른 엔진에는 하나의
픽스처를 적재할 수 없고, 컬럼의 의미가 다른 곳에서는 결과를 비교할 수 없습니다.

| Divergence / 불일치 | Detail / 내용 |
| --- | --- |
| `customer.c_last_review_date` | `char(10)` in Oracle, PostgreSQL, Vertica and StarRocks; `c_last_review_date_sk UInt32` in ClickHouse. ClickHouse follows the newer TPC-DS revision. The fixture emits a date surrogate key, which satisfies both. / ClickHouse 만 신 리비전을 따릅니다. 픽스처는 양쪽을 모두 만족하는 날짜 대리키를 출력합니다. |
| `store.s_tax_precentage` | The TPC-DS specification contains this misspelling and four schemas preserve it; ClickHouse corrected it to `s_tax_percentage`. Each engine's schema and queries agree internally, so both work. / TPC-DS 규격의 오타를 네 스키마가 유지하고 ClickHouse 만 수정했습니다. 엔진별로 스키마와 쿼리가 내부적으로 일치하므로 양쪽 모두 동작합니다. |
| StarRocks fact-table column order | StarRocks requires the duplicate-key columns to lead the table, so **all six fact tables** are reordered relative to the TPC-DS field order. The loader sends an explicit `columns:` header; a positional load would write `ss_ticket_number` into `ss_item_sk`. / **6개 팩트 테이블 전부**가 재배열됩니다. 로더가 명시적 `columns:` 헤더를 전송하며, 위치 기반 적재는 값을 잘못된 컬럼에 기록합니다. |
| `dbgen_version` | Present in Oracle, PostgreSQL and Vertica; absent from the ClickHouse and StarRocks schemas. No query uses it and no data is loaded into it. / ClickHouse·StarRocks 스키마에는 없습니다. 어떤 쿼리도 사용하지 않고 데이터도 적재되지 않습니다. |
