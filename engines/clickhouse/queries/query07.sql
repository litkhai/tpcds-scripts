-- TPC-DS query 07 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_07.sql
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
    i_item_id,
    avg(ss_quantity) AS agg1,
    avg(ss_list_price) AS agg2,
    avg(ss_coupon_amt) AS agg3,
    avg(ss_sales_price) AS agg4
FROM store_sales, customer_demographics, date_dim, item, promotion
WHERE (ss_sold_date_sk = d_date_sk)
    AND (ss_item_sk = i_item_sk)
    AND (ss_cdemo_sk = cd_demo_sk)
    AND (ss_promo_sk = p_promo_sk)
    AND (cd_gender = 'M')
    AND (cd_marital_status = 'S')
    AND (cd_education_status = 'College')
    AND ((p_channel_email = 'N') OR (p_channel_event = 'N'))
    AND (d_year = 2000)
GROUP BY i_item_id
ORDER BY i_item_id
LIMIT 100;
