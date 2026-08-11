-- TPC-DS query 70 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_70.sql
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
    sum(ss_net_profit) AS total_sum,
    s_state,
    s_county,
    grouping(s_state) + grouping(s_county) AS lochierarchy,
    rank() OVER (PARTITION BY grouping(s_state) + grouping(s_county), multiIf(grouping(s_county) = 0, s_state, NULL) ORDER BY sum(ss_net_profit) DESC) AS rank_within_parent
FROM store_sales, date_dim AS d1, store
WHERE ((d1.d_month_seq >= 1200) AND (d1.d_month_seq <= (1200 + 11)))
    AND (d1.d_date_sk = ss_sold_date_sk)
    AND (s_store_sk = ss_store_sk)
    AND (s_state IN (
        SELECT s_state
        FROM
        (
            SELECT
                s_state AS s_state,
                rank() OVER (PARTITION BY s_state ORDER BY sum(ss_net_profit) DESC) AS ranking
            FROM store_sales, store, date_dim
            WHERE ((d_month_seq >= 1200) AND (d_month_seq <= (1200 + 11)))
                AND (d_date_sk = ss_sold_date_sk)
                AND (s_store_sk = ss_store_sk)
            GROUP BY s_state
        ) AS tmp1
        WHERE (ranking <= 5)
    ))
GROUP BY
    s_state,
    s_county
    WITH ROLLUP
ORDER BY
    lochierarchy DESC,
    multiIf(lochierarchy = 0, s_state, NULL),
    rank_within_parent
LIMIT 100;
