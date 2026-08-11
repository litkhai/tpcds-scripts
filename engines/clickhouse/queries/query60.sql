-- TPC-DS query 60 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_60.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result;
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
WITH
    ss AS
    (
        SELECT
            i_item_id,
            sum(ss_ext_sales_price) AS total_sales
        FROM store_sales, date_dim, customer_address, item
        WHERE (i_item_id IN (
            SELECT i_item_id
            FROM item
            WHERE (i_category IN ('Music'))
        ))
            AND (ss_item_sk = i_item_sk)
            AND (ss_sold_date_sk = d_date_sk)
            AND (d_year = 1998)
            AND (d_moy = 9)
            AND (ss_addr_sk = ca_address_sk)
            AND (ca_gmt_offset = -5)
        GROUP BY i_item_id
    ),
    cs AS
    (
        SELECT
            i_item_id,
            sum(cs_ext_sales_price) AS total_sales
        FROM catalog_sales, date_dim, customer_address, item
        WHERE (i_item_id IN (
            SELECT i_item_id
            FROM item
            WHERE (i_category IN ('Music'))
        ))
            AND (cs_item_sk = i_item_sk)
            AND (cs_sold_date_sk = d_date_sk)
            AND (d_year = 1998)
            AND (d_moy = 9)
            AND (cs_bill_addr_sk = ca_address_sk)
            AND (ca_gmt_offset = -5)
        GROUP BY i_item_id
    ),
    ws AS
    (
        SELECT
            i_item_id,
            sum(ws_ext_sales_price) AS total_sales
        FROM web_sales, date_dim, customer_address, item
        WHERE (i_item_id IN (
            SELECT i_item_id
            FROM item
            WHERE (i_category IN ('Music'))
        ))
            AND (ws_item_sk = i_item_sk)
            AND (ws_sold_date_sk = d_date_sk)
            AND (d_year = 1998)
            AND (d_moy = 9)
            AND (ws_bill_addr_sk = ca_address_sk)
            AND (ca_gmt_offset = -5)
        GROUP BY i_item_id
    )
SELECT
    i_item_id,
    sum(total_sales) AS total_sales
FROM
(
    SELECT * FROM ss
    UNION ALL
    SELECT * FROM cs
    UNION ALL
    SELECT * FROM ws
) AS tmp1
GROUP BY i_item_id
ORDER BY
    i_item_id,
    total_sales
LIMIT 100;
