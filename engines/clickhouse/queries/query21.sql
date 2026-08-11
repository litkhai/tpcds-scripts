-- TPC-DS query 21 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_21.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
SELECT *
FROM
(
    SELECT
        w_warehouse_name,
        i_item_id,
        sum(CASE WHEN (CAST(d_date AS date) < CAST('2000-03-11' AS date)) THEN inv_quantity_on_hand ELSE 0 END) AS inv_before,
        sum(CASE WHEN (CAST(d_date AS date) >= CAST('2000-03-11' AS date)) THEN inv_quantity_on_hand ELSE 0 END) AS inv_after
    FROM inventory, warehouse, item, date_dim
    WHERE (i_current_price BETWEEN 0.99 AND 1.49)
        AND (i_item_sk = inv_item_sk)
        AND (inv_warehouse_sk = w_warehouse_sk)
        AND (inv_date_sk = d_date_sk)
        AND (d_date BETWEEN (CAST('2000-03-11' AS date) - INTERVAL 30 DAY) AND (CAST('2000-03-11' AS date) + INTERVAL 30 DAY))
    GROUP BY w_warehouse_name, i_item_id
) AS x
WHERE (CASE WHEN inv_before > 0 THEN inv_after / inv_before ELSE NULL END) BETWEEN 2.0 / 3.0 AND 3.0 / 2.0
ORDER BY
    w_warehouse_name,
    i_item_id
LIMIT 100;
