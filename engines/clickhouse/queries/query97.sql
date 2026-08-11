-- TPC-DS query 97 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_97.sql
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
    ssci AS
    (
        SELECT
            ss_customer_sk AS customer_sk,
            ss_item_sk AS item_sk
        FROM store_sales, date_dim
        WHERE (ss_sold_date_sk = d_date_sk)
            AND (d_month_seq BETWEEN 1200 AND 1200 + 11)
        GROUP BY
            ss_customer_sk,
            ss_item_sk
    ),
    csci AS
    (
        SELECT
            cs_bill_customer_sk AS customer_sk,
            cs_item_sk AS item_sk
        FROM catalog_sales, date_dim
        WHERE (cs_sold_date_sk = d_date_sk)
            AND (d_month_seq BETWEEN 1200 AND 1200 + 11)
        GROUP BY
            cs_bill_customer_sk,
            cs_item_sk
    )
SELECT
    sum(CASE WHEN (ssci.customer_sk IS NOT NULL) AND (csci.customer_sk IS NULL) THEN 1 ELSE 0 END) AS store_only,
    sum(CASE WHEN (ssci.customer_sk IS NULL) AND (csci.customer_sk IS NOT NULL) THEN 1 ELSE 0 END) AS catalog_only,
    sum(CASE WHEN (ssci.customer_sk IS NOT NULL) AND (csci.customer_sk IS NOT NULL) THEN 1 ELSE 0 END) AS store_and_catalog
FROM ssci
FULL OUTER JOIN csci ON (ssci.customer_sk = csci.customer_sk) AND (ssci.item_sk = csci.item_sk)
LIMIT 100;
