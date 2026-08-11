-- TPC-DS query 51 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_51.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
WITH
    web_v1 AS
    (
        SELECT
            ws_item_sk AS item_sk,
            d_date,
            sum(sum(ws_sales_price)) OVER (PARTITION BY ws_item_sk ORDER BY d_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cume_sales
        FROM web_sales, date_dim
        WHERE (ws_sold_date_sk = d_date_sk)
            AND (d_month_seq BETWEEN 1200 AND 1200 + 11)
            AND (ws_item_sk IS NOT NULL)
        GROUP BY ws_item_sk, d_date
    ),
    store_v1 AS
    (
        SELECT
            ss_item_sk AS item_sk,
            d_date,
            sum(sum(ss_sales_price)) OVER (PARTITION BY ss_item_sk ORDER BY d_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cume_sales
        FROM store_sales, date_dim
        WHERE (ss_sold_date_sk = d_date_sk)
            AND (d_month_seq BETWEEN 1200 AND 1200 + 11)
            AND (ss_item_sk IS NOT NULL)
        GROUP BY ss_item_sk, d_date
    )
SELECT *
FROM
(
    SELECT
        item_sk,
        d_date,
        web_sales,
        store_sales,
        max(web_sales) OVER (PARTITION BY item_sk ORDER BY d_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS web_cumulative,
        max(store_sales) OVER (PARTITION BY item_sk ORDER BY d_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS store_cumulative
    FROM
    (
        SELECT
            CASE WHEN web.item_sk IS NOT NULL THEN web.item_sk ELSE store.item_sk END AS item_sk,
            CASE WHEN web.d_date IS NOT NULL THEN web.d_date ELSE store.d_date END AS d_date,
            web.cume_sales AS web_sales,
            store.cume_sales AS store_sales
        FROM web_v1 AS web
        FULL OUTER JOIN store_v1 AS store ON (web.item_sk = store.item_sk) AND (web.d_date = store.d_date)
    ) AS x
) AS y
WHERE (web_cumulative > store_cumulative)
ORDER BY item_sk, d_date
LIMIT 100;
