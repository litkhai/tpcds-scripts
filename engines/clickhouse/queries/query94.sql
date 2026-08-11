-- TPC-DS query 94 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_94.sql
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
    count(DISTINCT ws_order_number) AS "order count",
    sum(ws_ext_ship_cost) AS "total shipping cost",
    sum(ws_net_profit) AS "total net profit"
FROM web_sales AS ws1, date_dim, customer_address, web_site
WHERE (d_date BETWEEN '1999-2-01' AND (CAST('1999-2-01', 'date') + INTERVAL 60 DAY))
    AND (ws1.ws_ship_date_sk = d_date_sk)
    AND (ws1.ws_ship_addr_sk = ca_address_sk)
    AND (ca_state = 'IL')
    AND (ws1.ws_web_site_sk = web_site_sk)
    AND (web_company_name = 'pri')
    AND EXISTS (
        SELECT *
        FROM web_sales AS ws2
        WHERE (ws1.ws_order_number = ws2.ws_order_number)
            AND (ws1.ws_warehouse_sk <> ws2.ws_warehouse_sk)
    )
    AND NOT EXISTS (
        SELECT *
        FROM web_returns AS wr1
        WHERE (ws1.ws_order_number = wr1.wr_order_number)
    )
ORDER BY count(DISTINCT ws_order_number)
LIMIT 100;
