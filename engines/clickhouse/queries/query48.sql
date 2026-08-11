-- TPC-DS query 48 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_48.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result;
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
SELECT sum(ss_quantity)
FROM store_sales, store, customer_demographics, customer_address, date_dim
WHERE (s_store_sk = ss_store_sk)
    AND (ss_sold_date_sk = d_date_sk)
    AND (d_year = 2000)
    AND (
        (
            (cd_demo_sk = ss_cdemo_sk)
            AND (cd_marital_status = 'M')
            AND (cd_education_status = '4 yr Degree')
            AND (ss_sales_price BETWEEN 100.00 AND 150.00)
        )
        OR (
            (cd_demo_sk = ss_cdemo_sk)
            AND (cd_marital_status = 'D')
            AND (cd_education_status = '2 yr Degree')
            AND (ss_sales_price BETWEEN 50.00 AND 100.00)
        )
        OR (
            (cd_demo_sk = ss_cdemo_sk)
            AND (cd_marital_status = 'S')
            AND (cd_education_status = 'College')
            AND (ss_sales_price BETWEEN 150.00 AND 200.00)
        )
    )
    AND (
        (
            (ss_addr_sk = ca_address_sk)
            AND (ca_country = 'United States')
            AND (ca_state IN ('CO', 'OH', 'TX'))
            AND (ss_net_profit BETWEEN 0 AND 2000)
        )
        OR (
            (ss_addr_sk = ca_address_sk)
            AND (ca_country = 'United States')
            AND (ca_state IN ('OR', 'MN', 'KY'))
            AND (ss_net_profit BETWEEN 150 AND 3000)
        )
        OR (
            (ss_addr_sk = ca_address_sk)
            AND (ca_country = 'United States')
            AND (ca_state IN ('VA', 'CA', 'MS'))
            AND (ss_net_profit BETWEEN 50 AND 25000)
        )
    );
