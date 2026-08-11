-- TPC-DS query 18 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_18.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
-- Changed decimal to Nullable(decimal) as original columns are also Nullable

SELECT
    i_item_id,
    ca_country,
    ca_state,
    ca_county,
    avg(CAST(cs_quantity AS Nullable(decimal(12, 2)))) AS agg1,
    avg(CAST(cs_list_price AS Nullable(decimal(12, 2)))) AS agg2,
    avg(CAST(cs_coupon_amt AS Nullable(decimal(12, 2)))) AS agg3,
    avg(CAST(cs_sales_price AS Nullable(decimal(12, 2)))) AS agg4,
    avg(CAST(cs_net_profit AS Nullable(decimal(12, 2)))) AS agg5,
    avg(CAST(c_birth_year AS Nullable(decimal(12, 2)))) AS agg6,
    avg(CAST(cd1.cd_dep_count AS Nullable(decimal(12, 2)))) AS agg7
FROM catalog_sales, customer_demographics AS cd1, customer_demographics AS cd2, customer, customer_address, date_dim, item
WHERE (cs_sold_date_sk = d_date_sk)
    AND (cs_item_sk = i_item_sk)
    AND (cs_bill_cdemo_sk = cd1.cd_demo_sk)
    AND (cs_bill_customer_sk = c_customer_sk)
    AND (cd1.cd_gender = 'F')
    AND (cd1.cd_education_status = 'Unknown')
    AND (c_current_cdemo_sk = cd2.cd_demo_sk)
    AND (c_current_addr_sk = ca_address_sk)
    AND (c_birth_month IN (1, 6, 8, 9, 12, 2))
    AND (d_year = 1998)
    AND (ca_state IN ('MS', 'IN', 'ND', 'OK', 'NM', 'VA', 'MS'))
GROUP BY ROLLUP (i_item_id, ca_country, ca_state, ca_county)
ORDER BY
    ca_country,
    ca_state,
    ca_county,
    i_item_id
LIMIT 100;
