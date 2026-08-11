-- TPC-DS query 39 (formulation 2) — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_39.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim; the upstream file holds both formulations and was split
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result;
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--

WITH
    inv AS
    (
        SELECT
            w_warehouse_name,
            w_warehouse_sk,
            i_item_sk,
            d_moy,
            stdev,
            mean,
            CASE mean WHEN 0 THEN NULL ELSE stdev / mean END AS cov
        FROM
        (
            SELECT
                w_warehouse_name,
                w_warehouse_sk,
                i_item_sk,
                d_moy,
                stddev_samp(inv_quantity_on_hand) AS stdev,
                avg(inv_quantity_on_hand) AS mean
            FROM inventory, item, warehouse, date_dim
            WHERE (inv_item_sk = i_item_sk)
                AND (inv_warehouse_sk = w_warehouse_sk)
                AND (inv_date_sk = d_date_sk)
                AND (d_year = 2001)
            GROUP BY w_warehouse_name, w_warehouse_sk, i_item_sk, d_moy
        ) AS foo
        WHERE (CASE mean WHEN 0 THEN 0 ELSE stdev / mean END > 1)
    )
SELECT
    inv1.w_warehouse_sk,
    inv1.i_item_sk,
    inv1.d_moy,
    inv1.mean,
    inv1.cov,
    inv2.w_warehouse_sk,
    inv2.i_item_sk,
    inv2.d_moy,
    inv2.mean,
    inv2.cov
FROM inv AS inv1, inv AS inv2
WHERE (inv1.i_item_sk = inv2.i_item_sk)
    AND (inv1.w_warehouse_sk = inv2.w_warehouse_sk)
    AND (inv1.d_moy = 1)
    AND (inv2.d_moy = 1 + 1)
    AND (inv1.cov > 1.5)
ORDER BY inv1.w_warehouse_sk, inv1.i_item_sk, inv1.d_moy, inv1.mean, inv1.cov, inv2.d_moy, inv2.mean, inv2.cov;
