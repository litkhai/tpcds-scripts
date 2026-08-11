-- TPC-DS query 16 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_16.sql
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
    count(DISTINCT cs_order_number) AS "order count",
    sum(cs_ext_ship_cost) AS "total shipping cost",
    sum(cs_net_profit) AS "total net profit"
FROM catalog_sales AS cs1, date_dim, customer_address, call_center
WHERE (d_date BETWEEN '2002-2-01' AND (CAST('2002-2-01' AS date) + INTERVAL 60 DAY))
    AND (cs1.cs_ship_date_sk = d_date_sk)
    AND (cs1.cs_ship_addr_sk = ca_address_sk)
    AND (ca_state = 'GA')
    AND (cs1.cs_call_center_sk = cc_call_center_sk)
    AND (cc_county IN ('Williamson County', 'Williamson County', 'Williamson County', 'Williamson County', 'Williamson County'))
    AND EXISTS (
        SELECT *
        FROM catalog_sales AS cs2
        WHERE (cs1.cs_order_number = cs2.cs_order_number) AND (cs1.cs_warehouse_sk <> cs2.cs_warehouse_sk)
    )
    AND NOT EXISTS (
        SELECT *
        FROM catalog_returns AS cr1
        WHERE (cs1.cs_order_number = cr1.cr_order_number)
    )
ORDER BY count(DISTINCT cs_order_number)
LIMIT 100;

