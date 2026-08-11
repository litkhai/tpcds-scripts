-- TPC-DS query 14 (formulation 1) — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_14.sql
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
    cross_items AS
    (
        SELECT i_item_sk AS ss_item_sk
        FROM item,
        (
            SELECT
                iss.i_brand_id AS brand_id,
                iss.i_class_id AS class_id,
                iss.i_category_id AS category_id
            FROM store_sales, item AS iss, date_dim AS d1
            WHERE (ss_item_sk = iss.i_item_sk) AND (ss_sold_date_sk = d1.d_date_sk) AND (d1.d_year BETWEEN 1999 AND 1999 + 2)
            INTERSECT
            SELECT
                ics.i_brand_id,
                ics.i_class_id,
                ics.i_category_id
            FROM catalog_sales, item AS ics, date_dim AS d2
            WHERE (cs_item_sk = ics.i_item_sk) AND (cs_sold_date_sk = d2.d_date_sk) AND (d2.d_year BETWEEN 1999 AND 1999 + 2)
            INTERSECT
            SELECT
                iws.i_brand_id,
                iws.i_class_id,
                iws.i_category_id
            FROM web_sales, item AS iws, date_dim AS d3
            WHERE (ws_item_sk = iws.i_item_sk) AND (ws_sold_date_sk = d3.d_date_sk) AND (d3.d_year BETWEEN 1999 AND 1999 + 2)
        )
        WHERE (i_brand_id = brand_id) AND (i_class_id = class_id) AND (i_category_id = category_id)
    ),
    avg_sales AS
    (
        SELECT avg(quantity * list_price) AS average_sales
        FROM
        (
            SELECT
                ss_quantity AS quantity,
                ss_list_price AS list_price
            FROM store_sales, date_dim
            WHERE (ss_sold_date_sk = d_date_sk) AND (d_year BETWEEN 1999 AND 1999 + 2)
            UNION ALL
            SELECT
                cs_quantity AS quantity,
                cs_list_price AS list_price
            FROM catalog_sales, date_dim
            WHERE (cs_sold_date_sk = d_date_sk) AND (d_year BETWEEN 1999 AND 1999 + 2)
            UNION ALL
            SELECT
                ws_quantity AS quantity,
                ws_list_price AS list_price
            FROM web_sales, date_dim
            WHERE (ws_sold_date_sk = d_date_sk) AND (d_year BETWEEN 1999 AND 1999 + 2)
        ) AS x
    )
SELECT
    channel,
    i_brand_id,
    i_class_id,
    i_category_id,
    sum(sales),
    sum(number_sales)
FROM
(
    SELECT
        'store' AS channel,
        i_brand_id,
        i_class_id,
        i_category_id,
        sum(ss_quantity * ss_list_price) AS sales,
        count(*) AS number_sales
    FROM store_sales, item, date_dim
    WHERE (ss_item_sk IN (
        SELECT ss_item_sk
        FROM cross_items
    )) AND (ss_item_sk = i_item_sk) AND (ss_sold_date_sk = d_date_sk) AND (d_year = (1999 + 2)) AND (d_moy = 11)
    GROUP BY
        i_brand_id,
        i_class_id,
        i_category_id
    HAVING sum(ss_quantity * ss_list_price) > (
        SELECT average_sales
        FROM avg_sales
    )
    UNION ALL
    SELECT
        'catalog' AS channel,
        i_brand_id,
        i_class_id,
        i_category_id,
        sum(cs_quantity * cs_list_price) AS sales,
        count(*) AS number_sales
    FROM catalog_sales, item, date_dim
    WHERE (cs_item_sk IN (
        SELECT ss_item_sk
        FROM cross_items
    )) AND (cs_item_sk = i_item_sk) AND (cs_sold_date_sk = d_date_sk) AND (d_year = (1999 + 2)) AND (d_moy = 11)
    GROUP BY
        i_brand_id,
        i_class_id,
        i_category_id
    HAVING sum(cs_quantity * cs_list_price) > (
        SELECT average_sales
        FROM avg_sales
    )
    UNION ALL
    SELECT
        'web' AS channel,
        i_brand_id,
        i_class_id,
        i_category_id,
        sum(ws_quantity * ws_list_price) AS sales,
        count(*) AS number_sales
    FROM web_sales, item, date_dim
    WHERE (ws_item_sk IN (
        SELECT ss_item_sk
        FROM cross_items
    )) AND (ws_item_sk = i_item_sk) AND (ws_sold_date_sk = d_date_sk) AND (d_year = (1999 + 2)) AND (d_moy = 11)
    GROUP BY
        i_brand_id,
        i_class_id,
        i_category_id
    HAVING sum(ws_quantity * ws_list_price) > (
        SELECT average_sales
        FROM avg_sales
    )
) AS y
GROUP BY
    channel,
    i_brand_id,
    i_class_id,
    i_category_id
    WITH ROLLUP
ORDER BY
    channel,
    i_brand_id,
    i_class_id,
    i_category_id
LIMIT 100;
