-- TPC-DS query 68 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_68.sql
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
    c_last_name,
    c_first_name,
    ca_city,
    bought_city,
    ss_ticket_number,
    extended_price,
    extended_tax,
    list_price
FROM
(
    SELECT
        ss_ticket_number,
        ss_customer_sk,
        ca_city AS bought_city,
        sum(ss_ext_sales_price) AS extended_price,
        sum(ss_ext_list_price) AS list_price,
        sum(ss_ext_tax) AS extended_tax
    FROM store_sales, date_dim, store, household_demographics, customer_address
    WHERE (store_sales.ss_sold_date_sk = date_dim.d_date_sk)
        AND (store_sales.ss_store_sk = store.s_store_sk)
        AND (store_sales.ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND (store_sales.ss_addr_sk = customer_address.ca_address_sk)
        AND ((date_dim.d_dom >= 1) AND (date_dim.d_dom <= 2))
        AND ((household_demographics.hd_dep_count = 4) OR (household_demographics.hd_vehicle_count = 3))
        AND (date_dim.d_year IN (1999, 1999 + 1, 1999 + 2))
        AND (store.s_city IN ('Midway', 'Fairview'))
    GROUP BY
        ss_ticket_number,
        ss_customer_sk,
        ss_addr_sk,
        ca_city
) AS dn, customer, customer_address AS current_addr
WHERE (ss_customer_sk = c_customer_sk)
    AND (customer.c_current_addr_sk = current_addr.ca_address_sk)
    AND (current_addr.ca_city != bought_city)
ORDER BY
    c_last_name,
    ss_ticket_number
LIMIT 100;
