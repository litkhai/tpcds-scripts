-- TPC-DS query 52 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_52.sql
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
    dt.d_year,
    item.i_brand_id AS brand_id,
    item.i_brand AS brand,
    sum(ss_ext_sales_price) AS ext_price
FROM date_dim AS dt, store_sales, item
WHERE (dt.d_date_sk = store_sales.ss_sold_date_sk)
    AND (store_sales.ss_item_sk = item.i_item_sk)
    AND (item.i_manager_id = 1)
    AND (dt.d_moy = 11)
    AND (dt.d_year = 2000)
GROUP BY
    dt.d_year,
    item.i_brand,
    item.i_brand_id
ORDER BY
    dt.d_year,
    ext_price DESC,
    brand_id
LIMIT 100;
