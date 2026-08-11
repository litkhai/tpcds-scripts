-- TPC-DS query 84 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_84.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result;
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
-- There are null bytes in output. The rows use FixedString(N) type, but have less than N characters. The TPC-DS specification says:
-- `Char(N) means that the column shall be able to hold any string of characters of a fixed length of N`
-- But we then get strings of less than N characters and as result have the null bytes in the output. We deem such result as correct.
SELECT
    c_customer_id AS customer_id,
    concat(coalesce(c_last_name, ''), ', ', coalesce(c_first_name, '')) AS customername
FROM customer, customer_address, customer_demographics, household_demographics, income_band, store_returns
WHERE (ca_city = 'Edgewood')
    AND (c_current_addr_sk = ca_address_sk)
    AND (ib_lower_bound >= 38128)
    AND (ib_upper_bound <= (38128 + 50000))
    AND (ib_income_band_sk = hd_income_band_sk)
    AND (cd_demo_sk = c_current_cdemo_sk)
    AND (hd_demo_sk = c_current_hdemo_sk)
    AND (sr_cdemo_sk = cd_demo_sk)
ORDER BY c_customer_id
LIMIT 100;
