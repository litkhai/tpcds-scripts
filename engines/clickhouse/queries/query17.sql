-- TPC-DS query 17 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_17.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
-- Returns nan instead of NULL as stddev_samp is called on a single value: https://github.com/ClickHouse/ClickHouse/issues/94683

SELECT
    i_item_id,
    i_item_desc,
    s_state,
    count(ss_quantity) AS store_sales_quantitycount,
    avg(ss_quantity) AS store_sales_quantityave,
    stddev_samp(ss_quantity) AS store_sales_quantitystdev,
    stddev_samp(ss_quantity) / avg(ss_quantity) AS store_sales_quantitycov,
    count(sr_return_quantity) AS store_returns_quantitycount,
    avg(sr_return_quantity) AS store_returns_quantityave,
    stddev_samp(sr_return_quantity) AS store_returns_quantitystdev,
    stddev_samp(sr_return_quantity) / avg(sr_return_quantity) AS store_returns_quantitycov,
    count(cs_quantity) AS catalog_sales_quantitycount,
    avg(cs_quantity) AS catalog_sales_quantityave,
    stddev_samp(cs_quantity) AS catalog_sales_quantitystdev,
    stddev_samp(cs_quantity) / avg(cs_quantity) AS catalog_sales_quantitycov
FROM store_sales, store_returns, catalog_sales, date_dim AS d1, date_dim AS d2, date_dim AS d3, store, item
WHERE (d1.d_quarter_name = '2001Q1')
    AND (d1.d_date_sk = ss_sold_date_sk)
    AND (i_item_sk = ss_item_sk)
    AND (s_store_sk = ss_store_sk)
    AND (ss_customer_sk = sr_customer_sk)
    AND (ss_item_sk = sr_item_sk)
    AND (ss_ticket_number = sr_ticket_number)
    AND (sr_returned_date_sk = d2.d_date_sk)
    AND (d2.d_quarter_name IN ('2001Q1', '2001Q2', '2001Q3'))
    AND (sr_customer_sk = cs_bill_customer_sk)
    AND (sr_item_sk = cs_item_sk)
    AND (cs_sold_date_sk = d3.d_date_sk)
    AND (d3.d_quarter_name IN ('2001Q1', '2001Q2', '2001Q3'))
GROUP BY
    i_item_id,
    i_item_desc,
    s_state
ORDER BY
    i_item_id,
    i_item_desc,
    s_state
LIMIT 100;
