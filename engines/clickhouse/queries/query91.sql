-- TPC-DS query 91 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_91.sql
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
    cc_call_center_id AS Call_Center,
    cc_name AS Call_Center_Name,
    cc_manager AS Manager,
    sum(cr_net_loss) AS Returns_Loss
FROM call_center, catalog_returns, date_dim, customer, customer_address, customer_demographics, household_demographics
WHERE (cr_call_center_sk = cc_call_center_sk)
    AND (cr_returned_date_sk = d_date_sk)
    AND (cr_returning_customer_sk = c_customer_sk)
    AND (cd_demo_sk = c_current_cdemo_sk)
    AND (hd_demo_sk = c_current_hdemo_sk)
    AND (ca_address_sk = c_current_addr_sk)
    AND (d_year = 1998)
    AND (d_moy = 11)
    AND (
        ((cd_marital_status = 'M') AND (cd_education_status = 'Unknown'))
        OR ((cd_marital_status = 'W') AND (cd_education_status = 'Advanced Degree'))
    )
    AND (hd_buy_potential LIKE 'Unknown%')
    AND (ca_gmt_offset = -7)
GROUP BY
    cc_call_center_id,
    cc_name,
    cc_manager,
    cd_marital_status,
    cd_education_status
ORDER BY sum(cr_net_loss) DESC;
