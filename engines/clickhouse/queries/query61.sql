-- TPC-DS query 61 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_61.sql
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
    promotions,
    total,
    CAST(promotions AS decimal(15, 4)) / CAST(total AS decimal(15, 4)) * 100
FROM
(
    SELECT sum(ss_ext_sales_price) AS promotions
    FROM store_sales, store, promotion, date_dim, customer, customer_address, item
    WHERE (ss_sold_date_sk = d_date_sk)
        AND (ss_store_sk = s_store_sk)
        AND (ss_promo_sk = p_promo_sk)
        AND (ss_customer_sk = c_customer_sk)
        AND (ca_address_sk = c_current_addr_sk)
        AND (ss_item_sk = i_item_sk)
        AND (ca_gmt_offset = -5)
        AND (i_category = 'Jewelry')
        AND ((p_channel_dmail = 'Y') OR (p_channel_email = 'Y') OR (p_channel_tv = 'Y'))
        AND (s_gmt_offset = -5)
        AND (d_year = 1998)
        AND (d_moy = 11)
) AS promotional_sales,
(
    SELECT sum(ss_ext_sales_price) AS total
    FROM store_sales, store, date_dim, customer, customer_address, item
    WHERE (ss_sold_date_sk = d_date_sk)
        AND (ss_store_sk = s_store_sk)
        AND (ss_customer_sk = c_customer_sk)
        AND (ca_address_sk = c_current_addr_sk)
        AND (ss_item_sk = i_item_sk)
        AND (ca_gmt_offset = -5)
        AND (i_category = 'Jewelry')
        AND (s_gmt_offset = -5)
        AND (d_year = 1998)
        AND (d_moy = 11)
) AS all_sales
ORDER BY promotions, total
LIMIT 100;
