-- TPC-DS query 36 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_36.sql
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
    sum(ss_net_profit) / sum(ss_ext_sales_price) AS gross_margin,
    i_category,
    i_class,
    grouping(i_category) + grouping(i_class) AS lochierarchy,
    rank() OVER (
        PARTITION BY grouping(i_category) + grouping(i_class),
        CASE WHEN grouping(i_class) = 0 THEN i_category END
        ORDER BY (sum(ss_net_profit) * 1.) / sum(ss_ext_sales_price) ASC
    ) AS rank_within_parent
FROM store_sales, date_dim AS d1, item, store
WHERE (d1.d_year = 2001)
    AND (d1.d_date_sk = ss_sold_date_sk)
    AND (i_item_sk = ss_item_sk)
    AND (s_store_sk = ss_store_sk)
    AND (s_state IN ('TN', 'TN', 'TN', 'TN', 'TN', 'TN', 'TN', 'TN'))
GROUP BY ROLLUP(i_category, i_class)
ORDER BY
    lochierarchy DESC,
    CASE WHEN lochierarchy = 0 THEN i_category END,
    rank_within_parent
LIMIT 100;
