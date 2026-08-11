-- TPC-DS query 72 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_72.sql
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
    i_item_desc,
    w_warehouse_name,
    d1.d_week_seq,
    sum(multiIf(p_promo_sk IS NULL, 1, 0)) AS no_promo,
    sum(multiIf(p_promo_sk IS NOT NULL, 1, 0)) AS promo,
    count(*) AS total_cnt
FROM catalog_sales
INNER JOIN inventory ON cs_item_sk = inv_item_sk
INNER JOIN warehouse ON w_warehouse_sk = inv_warehouse_sk
INNER JOIN item ON i_item_sk = cs_item_sk
INNER JOIN customer_demographics ON cs_bill_cdemo_sk = cd_demo_sk
INNER JOIN household_demographics ON cs_bill_hdemo_sk = hd_demo_sk
INNER JOIN date_dim AS d1 ON cs_sold_date_sk = d1.d_date_sk
INNER JOIN date_dim AS d2 ON inv_date_sk = d2.d_date_sk
INNER JOIN date_dim AS d3 ON cs_ship_date_sk = d3.d_date_sk
LEFT JOIN promotion ON cs_promo_sk = p_promo_sk
LEFT JOIN catalog_returns ON (cr_item_sk = cs_item_sk) AND (cr_order_number = cs_order_number)
WHERE (d1.d_week_seq = d2.d_week_seq)
    AND (inv_quantity_on_hand < cs_quantity)
    AND (d3.d_date > (d1.d_date + 5))
    AND (hd_buy_potential = '>10000')
    AND (d1.d_year = 1999)
    AND (cd_marital_status = 'D')
GROUP BY
    i_item_desc,
    w_warehouse_name,
    d_week_seq
ORDER BY
    total_cnt DESC,
    i_item_desc,
    w_warehouse_name,
    d_week_seq
LIMIT 100;
