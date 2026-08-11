-- TPC-DS query 83 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_83.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result;
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
WITH
    sr_items AS
    (
        SELECT
            i_item_id AS item_id,
            sum(sr_return_quantity) AS sr_item_qty
        FROM store_returns, item, date_dim
        WHERE (sr_item_sk = i_item_sk)
            AND (d_date IN (
                SELECT d_date
                FROM date_dim
                WHERE (d_week_seq IN (
                    SELECT d_week_seq
                    FROM date_dim
                    WHERE (d_date IN ('2000-06-30', '2000-09-27', '2000-11-17'))
                ))
            ))
            AND (sr_returned_date_sk = d_date_sk)
        GROUP BY i_item_id
    ),
    cr_items AS
    (
        SELECT
            i_item_id AS item_id,
            sum(cr_return_quantity) AS cr_item_qty
        FROM catalog_returns, item, date_dim
        WHERE (cr_item_sk = i_item_sk)
            AND (d_date IN (
                SELECT d_date
                FROM date_dim
                WHERE (d_week_seq IN (
                    SELECT d_week_seq
                    FROM date_dim
                    WHERE (d_date IN ('2000-06-30', '2000-09-27', '2000-11-17'))
                ))
            ))
            AND (cr_returned_date_sk = d_date_sk)
        GROUP BY i_item_id
    ),
    wr_items AS
    (
        SELECT
            i_item_id AS item_id,
            sum(wr_return_quantity) AS wr_item_qty
        FROM web_returns, item, date_dim
        WHERE (wr_item_sk = i_item_sk)
            AND (d_date IN (
                SELECT d_date
                FROM date_dim
                WHERE (d_week_seq IN (
                    SELECT d_week_seq
                    FROM date_dim
                    WHERE (d_date IN ('2000-06-30', '2000-09-27', '2000-11-17'))
                ))
            ))
            AND (wr_returned_date_sk = d_date_sk)
        GROUP BY i_item_id
    )
SELECT
    sr_items.item_id,
    sr_item_qty,
    ((sr_item_qty / ((sr_item_qty + cr_item_qty) + wr_item_qty)) / 3.) * 100 AS sr_dev,
    cr_item_qty,
    ((cr_item_qty / ((sr_item_qty + cr_item_qty) + wr_item_qty)) / 3.) * 100 AS cr_dev,
    wr_item_qty,
    ((wr_item_qty / ((sr_item_qty + cr_item_qty) + wr_item_qty)) / 3.) * 100 AS wr_dev,
    ((sr_item_qty + cr_item_qty) + wr_item_qty) / 3. AS average
FROM sr_items, cr_items, wr_items
WHERE (sr_items.item_id = cr_items.item_id)
    AND (sr_items.item_id = wr_items.item_id)
ORDER BY
    sr_items.item_id,
    sr_item_qty
LIMIT 100;
