-- TPC-DS query 58 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_58.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result;
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
-- Rewritten: `order by item_id` -> `order by ss_items.item_id`.
-- By SQL standard, former should also work (Chapter 7.13, syntax rule 28, case ii).
-- Issue: https://github.com/ClickHouse/ClickHouse/issues/94976

-- Also added casts like sum(ss_ext_sales_price) ss_item_rev -> sum(CAST(ss_ext_sales_price AS Float64) ss_item_rev) for precision reasons.
-- This is legal in TPC-DS specification.

WITH
    ss_items AS
    (
        SELECT
            i_item_id AS item_id,
            sum(ss_ext_sales_price) AS ss_item_rev
        FROM store_sales, item, date_dim
        WHERE (ss_item_sk = i_item_sk)
            AND (d_date IN (
                SELECT d_date
                FROM date_dim
                WHERE (d_week_seq = (
                    SELECT d_week_seq
                    FROM date_dim
                    WHERE (d_date = '2000-01-03')
                ))
            ))
            AND (ss_sold_date_sk = d_date_sk)
        GROUP BY i_item_id
    ),
    cs_items AS
    (
        SELECT
            i_item_id AS item_id,
            sum(cs_ext_sales_price) AS cs_item_rev
        FROM catalog_sales, item, date_dim
        WHERE (cs_item_sk = i_item_sk)
            AND (d_date IN (
                SELECT d_date
                FROM date_dim
                WHERE (d_week_seq = (
                    SELECT d_week_seq
                    FROM date_dim
                    WHERE (d_date = '2000-01-03')
                ))
            ))
            AND (cs_sold_date_sk = d_date_sk)
        GROUP BY i_item_id
    ),
    ws_items AS
    (
        SELECT
            i_item_id AS item_id,
            sum(ws_ext_sales_price) AS ws_item_rev
        FROM web_sales, item, date_dim
        WHERE (ws_item_sk = i_item_sk)
            AND (d_date IN (
                SELECT d_date
                FROM date_dim
                WHERE (d_week_seq = (
                    SELECT d_week_seq
                    FROM date_dim
                    WHERE (d_date = '2000-01-03')
                ))
            ))
            AND (ws_sold_date_sk = d_date_sk)
        GROUP BY i_item_id
    )
SELECT
    ss_items.item_id,
    ss_item_rev,
    ss_item_rev / ((CAST(ss_item_rev AS Float64) + cs_item_rev + ws_item_rev) / 3) * 100 AS ss_dev,
    cs_item_rev,
    cs_item_rev / ((CAST(ss_item_rev AS Float64) + cs_item_rev + ws_item_rev) / 3) * 100 AS cs_dev,
    ws_item_rev,
    ws_item_rev / ((CAST(ss_item_rev AS Float64) + cs_item_rev + ws_item_rev) / 3) * 100 AS ws_dev,
    (ss_item_rev + cs_item_rev + ws_item_rev) / 3 AS average
FROM ss_items, cs_items, ws_items
WHERE (ss_items.item_id = cs_items.item_id)
    AND (ss_items.item_id = ws_items.item_id)
    AND (ss_item_rev BETWEEN 0.9 * cs_item_rev AND 1.1 * cs_item_rev)
    AND (ss_item_rev BETWEEN 0.9 * ws_item_rev AND 1.1 * ws_item_rev)
    AND (cs_item_rev BETWEEN 0.9 * ss_item_rev AND 1.1 * ss_item_rev)
    AND (cs_item_rev BETWEEN 0.9 * ws_item_rev AND 1.1 * ws_item_rev)
    AND (ws_item_rev BETWEEN 0.9 * ss_item_rev AND 1.1 * ss_item_rev)
    AND (ws_item_rev BETWEEN 0.9 * cs_item_rev AND 1.1 * cs_item_rev)
ORDER BY
    ss_items.item_id,
    ss_item_rev
LIMIT 100;
