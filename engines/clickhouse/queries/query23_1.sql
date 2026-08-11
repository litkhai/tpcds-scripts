-- TPC-DS query 23 (formulation 1) — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_23.sql
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
    frequent_ss_items AS
    (
        SELECT
            substr(i_item_desc, 1, 30) AS itemdesc,
            i_item_sk AS item_sk,
            d_date AS solddate,
            count(*) AS cnt
        FROM store_sales, date_dim, item
        WHERE (ss_sold_date_sk = d_date_sk)
            AND (ss_item_sk = i_item_sk)
            AND (d_year IN (2000, 2000 + 1, 2000 + 2, 2000 + 3))
        GROUP BY substr(i_item_desc, 1, 30), i_item_sk, d_date
        HAVING count(*) > 4
    ),
    max_store_sales AS
    (
        SELECT max(csales) AS tpcds_cmax
        FROM
        (
            SELECT
                c_customer_sk,
                sum(ss_quantity * ss_sales_price) AS csales
            FROM store_sales, customer, date_dim
            WHERE (ss_customer_sk = c_customer_sk)
                AND (ss_sold_date_sk = d_date_sk)
                AND (d_year IN (2000, 2000 + 1, 2000 + 2, 2000 + 3))
            GROUP BY c_customer_sk
        )
    ),
    best_ss_customer AS
    (
        SELECT
            c_customer_sk,
            sum(ss_quantity * ss_sales_price) AS ssales
        FROM store_sales, customer
        WHERE (ss_customer_sk = c_customer_sk)
        GROUP BY c_customer_sk
        HAVING sum(ss_quantity * ss_sales_price) > (50 / 100.0) * (
            SELECT *
            FROM max_store_sales
        )
    )
SELECT sum(sales)
FROM
(
    SELECT cs_quantity * cs_list_price AS sales
    FROM catalog_sales, date_dim
    WHERE (d_year = 2000)
        AND (d_moy = 2)
        AND (cs_sold_date_sk = d_date_sk)
        AND (cs_item_sk IN (SELECT item_sk FROM frequent_ss_items))
        AND (cs_bill_customer_sk IN (SELECT c_customer_sk FROM best_ss_customer))
    UNION ALL
    SELECT ws_quantity * ws_list_price AS sales
    FROM web_sales, date_dim
    WHERE (d_year = 2000)
        AND (d_moy = 2)
        AND (ws_sold_date_sk = d_date_sk)
        AND (ws_item_sk IN (SELECT item_sk FROM frequent_ss_items))
        AND (ws_bill_customer_sk IN (SELECT c_customer_sk FROM best_ss_customer))
)
LIMIT 100;
