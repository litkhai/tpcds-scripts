-- TPC-DS query 44 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_44.sql
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
    asceding.rnk,
    i1.i_product_name AS best_performing,
    i2.i_product_name AS worst_performing
FROM
(
    SELECT *
    FROM
    (
        SELECT
            item_sk,
            rank() OVER (ORDER BY rank_col ASC) AS rnk
        FROM
        (
            SELECT
                ss_item_sk AS item_sk,
                avg(ss_net_profit) AS rank_col
            FROM store_sales AS ss1
            WHERE (ss_store_sk = 4)
            GROUP BY ss_item_sk
            HAVING avg(ss_net_profit) > 0.9 * (
                SELECT avg(ss_net_profit) AS rank_col
                FROM store_sales
                WHERE (ss_store_sk = 4) AND (ss_addr_sk IS NULL)
                GROUP BY ss_store_sk
            )
        ) AS V1
    ) AS V11
    WHERE (rnk < 11)
) AS asceding,
(
    SELECT *
    FROM
    (
        SELECT
            item_sk,
            rank() OVER (ORDER BY rank_col DESC) AS rnk
        FROM
        (
            SELECT
                ss_item_sk AS item_sk,
                avg(ss_net_profit) AS rank_col
            FROM store_sales AS ss1
            WHERE (ss_store_sk = 4)
            GROUP BY ss_item_sk
            HAVING avg(ss_net_profit) > 0.9 * (
                SELECT avg(ss_net_profit) AS rank_col
                FROM store_sales
                WHERE (ss_store_sk = 4) AND (ss_addr_sk IS NULL)
                GROUP BY ss_store_sk
            )
        ) AS V2
    ) AS V21
    WHERE (rnk < 11)
) AS descending,
item AS i1,
item AS i2
WHERE (asceding.rnk = descending.rnk)
    AND (i1.i_item_sk = asceding.item_sk)
    AND (i2.i_item_sk = descending.item_sk)
ORDER BY asceding.rnk
LIMIT 100;
