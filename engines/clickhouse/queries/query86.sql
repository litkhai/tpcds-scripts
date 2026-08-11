-- TPC-DS query 86 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_86.sql
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
    sum(ws_net_paid) AS total_sum,
    i_category,
    i_class,
    grouping(i_category) + grouping(i_class) AS lochierarchy,
    rank() OVER (PARTITION BY grouping(i_category) + grouping(i_class), multiIf(grouping(i_class) = 0, i_category, NULL) ORDER BY sum(ws_net_paid) DESC) AS rank_within_parent
FROM web_sales, date_dim AS d1, item
WHERE ((d1.d_month_seq >= 1200) AND (d1.d_month_seq <= (1200 + 11)))
    AND (d1.d_date_sk = ws_sold_date_sk)
    AND (i_item_sk = ws_item_sk)
GROUP BY
    i_category,
    i_class
    WITH ROLLUP
ORDER BY
    lochierarchy DESC,
    multiIf(lochierarchy = 0, i_category, NULL),
    rank_within_parent
LIMIT 100;
