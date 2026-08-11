-- TPC-DS query 54 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_54.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result;
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
WITH
    my_customers AS
    (
        SELECT DISTINCT
            c_customer_sk,
            c_current_addr_sk
        FROM
        (
            SELECT
                cs_sold_date_sk AS sold_date_sk,
                cs_bill_customer_sk AS customer_sk,
                cs_item_sk AS item_sk
            FROM catalog_sales
            UNION ALL
            SELECT
                ws_sold_date_sk AS sold_date_sk,
                ws_bill_customer_sk AS customer_sk,
                ws_item_sk AS item_sk
            FROM web_sales
        ) AS cs_or_ws_sales, item, date_dim, customer
        WHERE (sold_date_sk = d_date_sk)
            AND (item_sk = i_item_sk)
            AND (i_category = 'Women')
            AND (i_class = 'maternity')
            AND (c_customer_sk = cs_or_ws_sales.customer_sk)
            AND (d_moy = 12)
            AND (d_year = 1998)
    ),
    my_revenue AS
    (
        SELECT
            c_customer_sk,
            sum(ss_ext_sales_price) AS revenue
        FROM my_customers, store_sales, customer_address, store, date_dim
        WHERE (c_current_addr_sk = ca_address_sk)
            AND (ca_county = s_county)
            AND (ca_state = s_state)
            AND (ss_sold_date_sk = d_date_sk)
            AND (c_customer_sk = ss_customer_sk)
            AND (d_month_seq BETWEEN (
                SELECT DISTINCT d_month_seq + 1
                FROM date_dim
                WHERE (d_year = 1998) AND (d_moy = 12)
            ) AND (
                SELECT DISTINCT d_month_seq + 3
                FROM date_dim
                WHERE (d_year = 1998) AND (d_moy = 12)
            ))
        GROUP BY c_customer_sk
    ),
    segments AS
    (
        SELECT CAST((revenue / 50) AS int) AS segment
        FROM my_revenue
    )
SELECT
    segment,
    count(*) AS num_customers,
    segment * 50 AS segment_base
FROM segments
GROUP BY segment
ORDER BY segment, num_customers
LIMIT 100;
