-- TPC-DS query 24 (formulation 2) — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_24.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim; the upstream file holds both formulations and was split
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--


WITH
    ssales AS
    (
        SELECT
            c_last_name,
            c_first_name,
            s_store_name,
            ca_state,
            s_state,
            i_color,
            i_current_price,
            i_manager_id,
            i_units,
            i_size,
            sum(ss_net_paid) AS netpaid
        FROM store_sales, store_returns, store, item, customer, customer_address
        WHERE (ss_ticket_number = sr_ticket_number)
            AND (ss_item_sk = sr_item_sk)
            AND (ss_customer_sk = c_customer_sk)
            AND (ss_item_sk = i_item_sk)
            AND (ss_store_sk = s_store_sk)
            AND (c_current_addr_sk = ca_address_sk)
            AND (c_birth_country <> upper(ca_country))
            AND (s_zip = ca_zip)
            AND (s_market_id = 8)
        GROUP BY
            c_last_name,
            c_first_name,
            s_store_name,
            ca_state,
            s_state,
            i_color,
            i_current_price,
            i_manager_id,
            i_units,
            i_size
    )
SELECT
    c_last_name,
    c_first_name,
    s_store_name,
    sum(netpaid) AS paid
FROM ssales
WHERE (i_color = 'saddle')
GROUP BY
    c_last_name,
    c_first_name,
    s_store_name
HAVING sum(netpaid) > (
    SELECT 0.05 * avg(netpaid)
    FROM ssales
)
ORDER BY
    c_last_name,
    c_first_name,
    s_store_name;
