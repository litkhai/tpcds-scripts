-- TPC-DS query 15 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_15.sql
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
    ca_zip,
    sum(cs_sales_price)
FROM catalog_sales, customer, customer_address, date_dim
WHERE (cs_bill_customer_sk = c_customer_sk)
    AND (c_current_addr_sk = ca_address_sk)
    AND ((substr(ca_zip, 1, 5) IN ('85669', '86197', '88274', '83405', '86475', '85392', '85460', '80348', '81792'))
        OR (ca_state IN ('CA', 'WA', 'GA'))
        OR (cs_sales_price > 500))
    AND (cs_sold_date_sk = d_date_sk)
    AND (d_qoy = 2)
    AND (d_year = 2001)
GROUP BY ca_zip
ORDER BY ca_zip
LIMIT 100;

