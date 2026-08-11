-- TPC-DS query 37 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_37.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result;
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
SELECT
    i_item_id,
    i_item_desc,
    i_current_price
FROM item, inventory, date_dim, catalog_sales
WHERE (i_current_price BETWEEN 68 AND 68 + 30)
    AND (inv_item_sk = i_item_sk)
    AND (d_date_sk = inv_date_sk)
    AND (d_date BETWEEN CAST('2000-02-01' AS date) AND (CAST('2000-02-01' AS date) + INTERVAL 60 DAY))
    AND (i_manufact_id IN (677, 940, 694, 808))
    AND (inv_quantity_on_hand BETWEEN 100 AND 500)
    AND (cs_item_sk = i_item_sk)
GROUP BY i_item_id, i_item_desc, i_current_price
ORDER BY i_item_id
LIMIT 100;
