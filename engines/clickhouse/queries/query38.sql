-- TPC-DS query 38 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_38.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
SELECT count(*)
FROM
(
    SELECT DISTINCT c_last_name, c_first_name, d_date
    FROM store_sales, date_dim, customer
    WHERE (store_sales.ss_sold_date_sk = date_dim.d_date_sk)
        AND (store_sales.ss_customer_sk = customer.c_customer_sk)
        AND (d_month_seq BETWEEN 1200 AND 1200 + 11)
    INTERSECT
    SELECT DISTINCT c_last_name, c_first_name, d_date
    FROM catalog_sales, date_dim, customer
    WHERE (catalog_sales.cs_sold_date_sk = date_dim.d_date_sk)
        AND (catalog_sales.cs_bill_customer_sk = customer.c_customer_sk)
        AND (d_month_seq BETWEEN 1200 AND 1200 + 11)
    INTERSECT
    SELECT DISTINCT c_last_name, c_first_name, d_date
    FROM web_sales, date_dim, customer
    WHERE (web_sales.ws_sold_date_sk = date_dim.d_date_sk)
        AND (web_sales.ws_bill_customer_sk = customer.c_customer_sk)
        AND (d_month_seq BETWEEN 1200 AND 1200 + 11)
) AS hot_cust
LIMIT 100;
