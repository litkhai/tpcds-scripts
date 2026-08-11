-- TPC-DS query 06 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_06.sql
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
    a.ca_state AS state,
    count(*) AS cnt
FROM customer_address AS a, customer AS c, store_sales AS s, date_dim AS d, item AS i
WHERE (a.ca_address_sk = c.c_current_addr_sk)
    AND (c.c_customer_sk = s.ss_customer_sk)
    AND (s.ss_sold_date_sk = d.d_date_sk)
    AND (s.ss_item_sk = i.i_item_sk)
    AND (d.d_month_seq = (
        SELECT DISTINCT d_month_seq
        FROM date_dim
        WHERE (d_year = 2001) AND (d_moy = 1)
    ))
    AND (i.i_current_price > 1.2 * (
        SELECT avg(j.i_current_price)
        FROM item AS j
        WHERE (j.i_category = i.i_category)
    ))
GROUP BY a.ca_state
HAVING count(*) >= 10
ORDER BY cnt, a.ca_state
LIMIT 100;
