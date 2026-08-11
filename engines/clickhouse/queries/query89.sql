-- TPC-DS query 89 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_89.sql
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
        i_category,
        i_class,
        i_brand,
        s_store_name,
        s_company_name,
        d_moy,
        sum(ss_sales_price) AS sum_sales,
        avg(sum(ss_sales_price)) OVER (PARTITION BY i_category, i_brand, s_store_name, s_company_name) AS avg_monthly_sales
    FROM item, store_sales, date_dim, store
    WHERE (ss_item_sk = i_item_sk)
        AND (ss_sold_date_sk = d_date_sk)
        AND (ss_store_sk = s_store_sk)
        AND (d_year IN (1999))
        AND (
            ((i_category IN ('Women', 'Jewelry', 'Men')) AND (i_class IN ('dresses', 'birdal', 'shirts')))
            OR ((i_category IN ('Sports', 'Electronics', 'Books')) AND (i_class IN ('football', 'stereo', 'computers')))
        )
    GROUP BY
        i_category,
        i_class,
        i_brand,
        s_store_name,
        s_company_name,
        d_moy
) AS tmp1
WHERE (multiIf(avg_monthly_sales != 0, abs(sum_sales - avg_monthly_sales) / avg_monthly_sales, NULL) > 0.1)
ORDER BY
    sum_sales - avg_monthly_sales,
    s_store_name
LIMIT 100;
