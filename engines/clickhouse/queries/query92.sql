-- TPC-DS query 92 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_92.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result;
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
SELECT sum(ws_ext_discount_amt) AS `Excess Discount Amount`
FROM web_sales, item, date_dim
WHERE (i_manufact_id = 350)
    AND (i_item_sk = ws_item_sk)
    AND ((d_date >= '2000-01-27') AND (d_date <= (CAST('2000-01-27', 'date') + INTERVAL 90 DAY)))
    AND (d_date_sk = ws_sold_date_sk)
    AND (ws_ext_discount_amt > (
        SELECT 1.3 * avg(ws_ext_discount_amt)
        FROM web_sales, date_dim
        WHERE (ws_item_sk = i_item_sk)
            AND ((d_date >= '2000-01-27') AND (d_date <= (CAST('2000-01-27', 'date') + INTERVAL 90 DAY)))
            AND (d_date_sk = ws_sold_date_sk)
    ))
ORDER BY sum(ws_ext_discount_amt)
LIMIT 100;
