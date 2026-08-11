-- TPC-DS query 55 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_55.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
SELECT
    i_brand_id AS brand_id,
    i_brand AS brand,
    sum(ss_ext_sales_price) AS ext_price
FROM date_dim, store_sales, item
WHERE (d_date_sk = ss_sold_date_sk)
    AND (ss_item_sk = i_item_sk)
    AND (i_manager_id = 28)
    AND (d_moy = 11)
    AND (d_year = 1999)
GROUP BY i_brand, i_brand_id
ORDER BY ext_price DESC, i_brand_id
LIMIT 100;
