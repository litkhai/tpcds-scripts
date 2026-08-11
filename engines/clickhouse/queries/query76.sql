-- TPC-DS query 76 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_76.sql
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
    channel,
    col_name,
    d_year,
    d_qoy,
    i_category,
    COUNT(*) AS sales_cnt,
    SUM(ext_sales_price) AS sales_amt
FROM
(
    SELECT
        'store' AS channel,
        'ss_store_sk' AS col_name,
        d_year,
        d_qoy,
        i_category,
        ss_ext_sales_price AS ext_sales_price
    FROM store_sales, item, date_dim
    WHERE (ss_store_sk IS NULL)
        AND (ss_sold_date_sk = d_date_sk)
        AND (ss_item_sk = i_item_sk)
    UNION ALL
    SELECT
        'web' AS channel,
        'ws_ship_customer_sk' AS col_name,
        d_year,
        d_qoy,
        i_category,
        ws_ext_sales_price AS ext_sales_price
    FROM web_sales, item, date_dim
    WHERE (ws_ship_customer_sk IS NULL)
        AND (ws_sold_date_sk = d_date_sk)
        AND (ws_item_sk = i_item_sk)
    UNION ALL
    SELECT
        'catalog' AS channel,
        'cs_ship_addr_sk' AS col_name,
        d_year,
        d_qoy,
        i_category,
        cs_ext_sales_price AS ext_sales_price
    FROM catalog_sales, item, date_dim
    WHERE (cs_ship_addr_sk IS NULL)
        AND (cs_sold_date_sk = d_date_sk)
        AND (cs_item_sk = i_item_sk)
) AS foo
GROUP BY
    channel,
    col_name,
    d_year,
    d_qoy,
    i_category
ORDER BY
    channel,
    col_name,
    d_year,
    d_qoy,
    i_category
LIMIT 100;
