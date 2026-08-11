-- TPC-DS query 30 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_30.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
WITH
    customer_total_return AS
    (
        SELECT
            wr_returning_customer_sk AS ctr_customer_sk,
            ca_state AS ctr_state,
            sum(wr_return_amt) AS ctr_total_return
        FROM web_returns, date_dim, customer_address
        WHERE (wr_returned_date_sk = d_date_sk)
            AND (d_year = 2002)
            AND (wr_returning_addr_sk = ca_address_sk)
        GROUP BY
            wr_returning_customer_sk,
            ca_state
    )
SELECT
    c_customer_id,
    c_salutation,
    c_first_name,
    c_last_name,
    c_preferred_cust_flag,
    c_birth_day,
    c_birth_month,
    c_birth_year,
    c_birth_country,
    c_login,
    c_email_address,
    c_last_review_date_sk,
    ctr_total_return
FROM customer_total_return AS ctr1, customer_address, customer
WHERE (ctr1.ctr_total_return > (
    SELECT avg(ctr_total_return) * 1.2
    FROM customer_total_return AS ctr2
    WHERE (ctr1.ctr_state = ctr2.ctr_state)
))
    AND (ca_address_sk = c_current_addr_sk)
    AND (ca_state = 'GA')
    AND (ctr1.ctr_customer_sk = c_customer_sk)
ORDER BY
    c_customer_id,
    c_salutation,
    c_first_name,
    c_last_name,
    c_preferred_cust_flag,
    c_birth_day,
    c_birth_month,
    c_birth_year,
    c_birth_country,
    c_login,
    c_email_address,
    c_last_review_date_sk,
    ctr_total_return
LIMIT 100;
