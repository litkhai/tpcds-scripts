-- TPC-DS query 47 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_47.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
-- Before:
--  where  d_year = 1999 and
--        avg_monthly_sales > 0 and
--        case when avg_monthly_sales > 0 then abs(sum_sales - avg_monthly_sales) / avg_monthly_sales else null end > 0.1
--  order by sum_sales - avg_monthly_sales, s_store_name

-- After:
--  where  v1.d_year = 1999 and
--        v1.avg_monthly_sales > 0 and
--        case when v1.avg_monthly_sales > 0 then abs(v1.sum_sales - v1.avg_monthly_sales) / v1.avg_monthly_sales else null end > 0.1
--  order by v1.sum_sales - v1.avg_monthly_sales, v1.s_store_name

-- This is not explicitly allowed by the TPC-DS specification, must be fixed: https://github.com/ClickHouse/ClickHouse/issues/94858

WITH
    v1 AS
    (
        SELECT
            i_category,
            i_brand,
            s_store_name,
            s_company_name,
            d_year,
            d_moy,
            sum(ss_sales_price) AS sum_sales,
            avg(sum(ss_sales_price)) OVER (PARTITION BY i_category, i_brand, s_store_name, s_company_name, d_year) AS avg_monthly_sales,
            rank() OVER (PARTITION BY i_category, i_brand, s_store_name, s_company_name ORDER BY d_year, d_moy) AS rn
        FROM item, store_sales, date_dim, store
        WHERE (ss_item_sk = i_item_sk)
            AND (ss_sold_date_sk = d_date_sk)
            AND (ss_store_sk = s_store_sk)
            AND (
                (d_year = 1999)
                OR ((d_year = 1999 - 1) AND (d_moy = 12))
                OR ((d_year = 1999 + 1) AND (d_moy = 1))
            )
        GROUP BY i_category, i_brand, s_store_name, s_company_name, d_year, d_moy
    ),
    v2 AS
    (
        SELECT
            v1.i_category,
            v1.i_brand,
            v1.s_store_name,
            v1.s_company_name,
            v1.d_year,
            v1.d_moy,
            v1.avg_monthly_sales,
            v1.sum_sales,
            v1_lag.sum_sales AS psum,
            v1_lead.sum_sales AS nsum
        FROM v1, v1 AS v1_lag, v1 AS v1_lead
        WHERE (v1.i_category = v1_lag.i_category)
            AND (v1.i_category = v1_lead.i_category)
            AND (v1.i_brand = v1_lag.i_brand)
            AND (v1.i_brand = v1_lead.i_brand)
            AND (v1.s_store_name = v1_lag.s_store_name)
            AND (v1.s_store_name = v1_lead.s_store_name)
            AND (v1.s_company_name = v1_lag.s_company_name)
            AND (v1.s_company_name = v1_lead.s_company_name)
            AND (v1.rn = v1_lag.rn + 1)
            AND (v1.rn = v1_lead.rn - 1)
    )
SELECT *
FROM v2
WHERE (v1.d_year = 1999)
    AND (v1.avg_monthly_sales > 0)
    AND (CASE WHEN v1.avg_monthly_sales > 0 THEN abs(v1.sum_sales - v1.avg_monthly_sales) / v1.avg_monthly_sales ELSE NULL END > 0.1)
ORDER BY v1.sum_sales - v1.avg_monthly_sales, v1.s_store_name
LIMIT 100;
