-- TPC-DS query 12 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_12.sql
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
    i_category,
    i_class,
    i_current_price,
    sum(ws_ext_sales_price) AS itemrevenue,
    (sum(ws_ext_sales_price) * 100) / sum(sum(ws_ext_sales_price)) OVER (PARTITION BY i_class) AS revenueratio
FROM web_sales, item, date_dim
WHERE (ws_item_sk = i_item_sk) AND (i_category IN ('Sports', 'Books', 'Home')) AND (ws_sold_date_sk = d_date_sk) AND ((d_date >= CAST('1999-02-22', 'date')) AND (d_date <= (CAST('1999-02-22', 'date') + INTERVAL 30 day)))
GROUP BY
    i_item_id,
    i_item_desc,
    i_category,
    i_class,
    i_current_price
ORDER BY
    i_category,
    i_class,
    i_item_id,
    i_item_desc,
    revenueratio
LIMIT 100;

