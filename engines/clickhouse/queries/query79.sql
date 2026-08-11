-- TPC-DS query 79 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_79.sql
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
    substr(s_city, 1, 30),
    ss_ticket_number,
    amt,
    profit
FROM
(
    SELECT
        ss_ticket_number,
        ss_customer_sk,
        store.s_city,
        sum(ss_coupon_amt) AS amt,
        sum(ss_net_profit) AS profit
    FROM store_sales, date_dim, store, household_demographics
    WHERE (store_sales.ss_sold_date_sk = date_dim.d_date_sk)
        AND (store_sales.ss_store_sk = store.s_store_sk)
        AND (store_sales.ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND ((household_demographics.hd_dep_count = 6) OR (household_demographics.hd_vehicle_count > 2))
        AND (date_dim.d_dow = 1)
        AND (date_dim.d_year IN (1999, 1999 + 1, 1999 + 2))
        AND ((store.s_number_employees >= 200) AND (store.s_number_employees <= 295))
    GROUP BY
        ss_ticket_number,
        ss_customer_sk,
        ss_addr_sk,
        store.s_city
) AS ms, customer
WHERE (ss_customer_sk = c_customer_sk)
ORDER BY
    c_last_name,
    c_first_name,
    substr(s_city, 1, 30),
    profit
LIMIT 100;
