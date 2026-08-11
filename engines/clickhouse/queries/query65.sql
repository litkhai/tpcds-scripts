-- TPC-DS query 65 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_65.sql
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
    s_store_name,
    i_item_desc,
    sc.revenue,
    i_current_price,
    i_wholesale_cost,
    i_brand
FROM store, item,
(
    SELECT
        ss_store_sk,
        avg(revenue) AS ave
    FROM
    (
        SELECT
            ss_store_sk,
            ss_item_sk,
            sum(ss_sales_price) AS revenue
        FROM store_sales, date_dim
        WHERE ss_sold_date_sk = d_date_sk AND d_month_seq BETWEEN 1176 AND 1176+11
        GROUP BY
            ss_store_sk,
            ss_item_sk
    ) AS sa
    GROUP BY ss_store_sk
) AS sb,
(
    SELECT
        ss_store_sk,
        ss_item_sk,
        sum(ss_sales_price) AS revenue
    FROM store_sales, date_dim
    WHERE ss_sold_date_sk = d_date_sk AND d_month_seq BETWEEN 1176 AND 1176+11
    GROUP BY
        ss_store_sk,
        ss_item_sk
) AS sc
WHERE (sb.ss_store_sk = sc.ss_store_sk) AND (sc.revenue <= (0.1 * sb.ave)) AND (s_store_sk = sc.ss_store_sk) AND (i_item_sk = sc.ss_item_sk)
ORDER BY
    s_store_name,
    i_item_desc
LIMIT 100;