-- TPC-DS query 73 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_73.sql
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
    c_salutation,
    c_preferred_cust_flag,
    ss_ticket_number,
    cnt
FROM
(
    SELECT
        ss_ticket_number,
        ss_customer_sk,
        count(*) AS cnt
    FROM store_sales, date_dim, store, household_demographics
    WHERE (store_sales.ss_sold_date_sk = date_dim.d_date_sk)
        AND (store_sales.ss_store_sk = store.s_store_sk)
        AND (store_sales.ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND ((date_dim.d_dom >= 1) AND (date_dim.d_dom <= 2))
        AND ((household_demographics.hd_buy_potential = '>10000') OR (household_demographics.hd_buy_potential = 'Unknown'))
        AND (household_demographics.hd_vehicle_count > 0)
        AND (multiIf(household_demographics.hd_vehicle_count > 0, household_demographics.hd_dep_count / household_demographics.hd_vehicle_count, NULL) > 1)
        AND (date_dim.d_year IN (1999, 1999 + 1, 1999 + 2))
        AND (store.s_county IN ('Williamson County', 'Franklin Parish', 'Bronx County', 'Orange County'))
    GROUP BY
        ss_ticket_number,
        ss_customer_sk
) AS dj, customer
WHERE (ss_customer_sk = c_customer_sk)
    AND ((cnt >= 1) AND (cnt <= 5))
ORDER BY
    cnt DESC,
    c_last_name;
