-- TPC-DS query 59 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_59.sql
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
    wss AS
    (
        SELECT
            d_week_seq,
            ss_store_sk,
            sum(CASE WHEN (d_day_name = 'Sunday') THEN ss_sales_price ELSE NULL END) AS sun_sales,
            sum(CASE WHEN (d_day_name = 'Monday') THEN ss_sales_price ELSE NULL END) AS mon_sales,
            sum(CASE WHEN (d_day_name = 'Tuesday') THEN ss_sales_price ELSE NULL END) AS tue_sales,
            sum(CASE WHEN (d_day_name = 'Wednesday') THEN ss_sales_price ELSE NULL END) AS wed_sales,
            sum(CASE WHEN (d_day_name = 'Thursday') THEN ss_sales_price ELSE NULL END) AS thu_sales,
            sum(CASE WHEN (d_day_name = 'Friday') THEN ss_sales_price ELSE NULL END) AS fri_sales,
            sum(CASE WHEN (d_day_name = 'Saturday') THEN ss_sales_price ELSE NULL END) AS sat_sales
        FROM store_sales, date_dim
        WHERE (d_date_sk = ss_sold_date_sk)
        GROUP BY d_week_seq, ss_store_sk
    )
SELECT
    s_store_name1,
    s_store_id1,
    d_week_seq1,
    sun_sales1 / sun_sales2,
    mon_sales1 / mon_sales2,
    tue_sales1 / tue_sales2,
    wed_sales1 / wed_sales2,
    thu_sales1 / thu_sales2,
    fri_sales1 / fri_sales2,
    sat_sales1 / sat_sales2
FROM
(
    SELECT
        s_store_name AS s_store_name1,
        wss.d_week_seq AS d_week_seq1,
        s_store_id AS s_store_id1,
        sun_sales AS sun_sales1,
        mon_sales AS mon_sales1,
        tue_sales AS tue_sales1,
        wed_sales AS wed_sales1,
        thu_sales AS thu_sales1,
        fri_sales AS fri_sales1,
        sat_sales AS sat_sales1
    FROM wss, store, date_dim AS d
    WHERE (d.d_week_seq = wss.d_week_seq)
        AND (ss_store_sk = s_store_sk)
        AND (d_month_seq BETWEEN 1212 AND 1212 + 11)
) AS y,
(
    SELECT
        s_store_name AS s_store_name2,
        wss.d_week_seq AS d_week_seq2,
        s_store_id AS s_store_id2,
        sun_sales AS sun_sales2,
        mon_sales AS mon_sales2,
        tue_sales AS tue_sales2,
        wed_sales AS wed_sales2,
        thu_sales AS thu_sales2,
        fri_sales AS fri_sales2,
        sat_sales AS sat_sales2
    FROM wss, store, date_dim AS d
    WHERE (d.d_week_seq = wss.d_week_seq)
        AND (ss_store_sk = s_store_sk)
        AND (d_month_seq BETWEEN 1212 + 12 AND 1212 + 23)
) AS x
WHERE (s_store_id1 = s_store_id2)
    AND (d_week_seq1 = d_week_seq2 - 52)
ORDER BY s_store_name1, s_store_id1, d_week_seq1
LIMIT 100;
