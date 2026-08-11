-- TPC-DS query 88 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_88.sql
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
    SELECT count(*) AS h8_30_to_9
    FROM store_sales, household_demographics, time_dim, store
    WHERE (ss_sold_time_sk = time_dim.t_time_sk)
        AND (ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ss_store_sk = s_store_sk)
        AND (time_dim.t_hour = 8)
        AND (time_dim.t_minute >= 30)
        AND (
            ((household_demographics.hd_dep_count = 4) AND (household_demographics.hd_vehicle_count <= (4 + 2)))
            OR ((household_demographics.hd_dep_count = 2) AND (household_demographics.hd_vehicle_count <= (2 + 2)))
            OR ((household_demographics.hd_dep_count = 0) AND (household_demographics.hd_vehicle_count <= (0 + 2)))
        )
        AND (store.s_store_name = 'ese')
) AS s1,
(
    SELECT count(*) AS h9_to_9_30
    FROM store_sales, household_demographics, time_dim, store
    WHERE (ss_sold_time_sk = time_dim.t_time_sk)
        AND (ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ss_store_sk = s_store_sk)
        AND (time_dim.t_hour = 9)
        AND (time_dim.t_minute < 30)
        AND (
            ((household_demographics.hd_dep_count = 4) AND (household_demographics.hd_vehicle_count <= (4 + 2)))
            OR ((household_demographics.hd_dep_count = 2) AND (household_demographics.hd_vehicle_count <= (2 + 2)))
            OR ((household_demographics.hd_dep_count = 0) AND (household_demographics.hd_vehicle_count <= (0 + 2)))
        )
        AND (store.s_store_name = 'ese')
) AS s2,
(
    SELECT count(*) AS h9_30_to_10
    FROM store_sales, household_demographics, time_dim, store
    WHERE (ss_sold_time_sk = time_dim.t_time_sk)
        AND (ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ss_store_sk = s_store_sk)
        AND (time_dim.t_hour = 9)
        AND (time_dim.t_minute >= 30)
        AND (
            ((household_demographics.hd_dep_count = 4) AND (household_demographics.hd_vehicle_count <= (4 + 2)))
            OR ((household_demographics.hd_dep_count = 2) AND (household_demographics.hd_vehicle_count <= (2 + 2)))
            OR ((household_demographics.hd_dep_count = 0) AND (household_demographics.hd_vehicle_count <= (0 + 2)))
        )
        AND (store.s_store_name = 'ese')
) AS s3,
(
    SELECT count(*) AS h10_to_10_30
    FROM store_sales, household_demographics, time_dim, store
    WHERE (ss_sold_time_sk = time_dim.t_time_sk)
        AND (ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ss_store_sk = s_store_sk)
        AND (time_dim.t_hour = 10)
        AND (time_dim.t_minute < 30)
        AND (
            ((household_demographics.hd_dep_count = 4) AND (household_demographics.hd_vehicle_count <= (4 + 2)))
            OR ((household_demographics.hd_dep_count = 2) AND (household_demographics.hd_vehicle_count <= (2 + 2)))
            OR ((household_demographics.hd_dep_count = 0) AND (household_demographics.hd_vehicle_count <= (0 + 2)))
        )
        AND (store.s_store_name = 'ese')
) AS s4,
(
    SELECT count(*) AS h10_30_to_11
    FROM store_sales, household_demographics, time_dim, store
    WHERE (ss_sold_time_sk = time_dim.t_time_sk)
        AND (ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ss_store_sk = s_store_sk)
        AND (time_dim.t_hour = 10)
        AND (time_dim.t_minute >= 30)
        AND (
            ((household_demographics.hd_dep_count = 4) AND (household_demographics.hd_vehicle_count <= (4 + 2)))
            OR ((household_demographics.hd_dep_count = 2) AND (household_demographics.hd_vehicle_count <= (2 + 2)))
            OR ((household_demographics.hd_dep_count = 0) AND (household_demographics.hd_vehicle_count <= (0 + 2)))
        )
        AND (store.s_store_name = 'ese')
) AS s5,
(
    SELECT count(*) AS h11_to_11_30
    FROM store_sales, household_demographics, time_dim, store
    WHERE (ss_sold_time_sk = time_dim.t_time_sk)
        AND (ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ss_store_sk = s_store_sk)
        AND (time_dim.t_hour = 11)
        AND (time_dim.t_minute < 30)
        AND (
            ((household_demographics.hd_dep_count = 4) AND (household_demographics.hd_vehicle_count <= (4 + 2)))
            OR ((household_demographics.hd_dep_count = 2) AND (household_demographics.hd_vehicle_count <= (2 + 2)))
            OR ((household_demographics.hd_dep_count = 0) AND (household_demographics.hd_vehicle_count <= (0 + 2)))
        )
        AND (store.s_store_name = 'ese')
) AS s6,
(
    SELECT count(*) AS h11_30_to_12
    FROM store_sales, household_demographics, time_dim, store
    WHERE (ss_sold_time_sk = time_dim.t_time_sk)
        AND (ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ss_store_sk = s_store_sk)
        AND (time_dim.t_hour = 11)
        AND (time_dim.t_minute >= 30)
        AND (
            ((household_demographics.hd_dep_count = 4) AND (household_demographics.hd_vehicle_count <= (4 + 2)))
            OR ((household_demographics.hd_dep_count = 2) AND (household_demographics.hd_vehicle_count <= (2 + 2)))
            OR ((household_demographics.hd_dep_count = 0) AND (household_demographics.hd_vehicle_count <= (0 + 2)))
        )
        AND (store.s_store_name = 'ese')
) AS s7,
(
    SELECT count(*) AS h12_to_12_30
    FROM store_sales, household_demographics, time_dim, store
    WHERE (ss_sold_time_sk = time_dim.t_time_sk)
        AND (ss_hdemo_sk = household_demographics.hd_demo_sk)
        AND (ss_store_sk = s_store_sk)
        AND (time_dim.t_hour = 12)
        AND (time_dim.t_minute < 30)
        AND (
            ((household_demographics.hd_dep_count = 4) AND (household_demographics.hd_vehicle_count <= (4 + 2)))
            OR ((household_demographics.hd_dep_count = 2) AND (household_demographics.hd_vehicle_count <= (2 + 2)))
            OR ((household_demographics.hd_dep_count = 0) AND (household_demographics.hd_vehicle_count <= (0 + 2)))
        )
        AND (store.s_store_name = 'ese')
) AS s8;
