-- TPC-DS query 93 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_93.sql
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
    ss_customer_sk,
    sum(act_sales) AS sumsales
FROM
(
    SELECT
        ss_item_sk,
        ss_ticket_number,
        ss_customer_sk,
        multiIf(sr_return_quantity IS NOT NULL, (ss_quantity - sr_return_quantity) * ss_sales_price, ss_quantity * ss_sales_price) AS act_sales
    FROM store_sales
    LEFT JOIN store_returns ON (sr_item_sk = ss_item_sk) AND (sr_ticket_number = ss_ticket_number), reason
    WHERE (sr_reason_sk = r_reason_sk)
        AND (r_reason_desc = 'reason 28')
) AS t
GROUP BY ss_customer_sk
ORDER BY
    sumsales,
    ss_customer_sk
LIMIT 100;
