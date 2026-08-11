-- TPC-DS query 90 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_90.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
SELECT CAST(amc AS DECIMAL(15, 4)) / CAST(pmc AS DECIMAL(15, 4)) AS am_pm_ratio
FROM
(
    SELECT count(*) AS amc
    FROM web_sales, household_demographics, time_dim, web_page
    WHERE (ws_sold_time_sk = time_dim.t_time_sk)
        AND (ws_ship_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ws_web_page_sk = web_page.wp_web_page_sk)
        AND (time_dim.t_hour BETWEEN 8 AND 8 + 1)
        AND (household_demographics.hd_dep_count = 6)
        AND (web_page.wp_char_count BETWEEN 5000 AND 5200)
) AS at,
(
    SELECT count(*) AS pmc
    FROM web_sales, household_demographics, time_dim, web_page
    WHERE (ws_sold_time_sk = time_dim.t_time_sk)
        AND (ws_ship_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ws_web_page_sk = web_page.wp_web_page_sk)
        AND (time_dim.t_hour BETWEEN 19 AND 19 + 1)
        AND (household_demographics.hd_dep_count = 6)
        AND (web_page.wp_char_count BETWEEN 5000 AND 5200)
) AS pt
ORDER BY am_pm_ratio
LIMIT 100;
