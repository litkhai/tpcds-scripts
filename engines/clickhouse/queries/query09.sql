-- TPC-DS query 09 — ClickHouse
--
-- Upstream / 상류 출처: ClickHouse/ClickHouse @ 4efb1206aa13
--   tests/benchmarks/tpc-ds/queries/query_09.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: none — imported verbatim
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
SELECT
    multiIf((
        SELECT count(*)
        FROM store_sales
        WHERE (ss_quantity >= 1) AND (ss_quantity <= 20)
    ) > 74129, (
        SELECT avg(ss_ext_discount_amt)
        FROM store_sales
        WHERE (ss_quantity >= 1) AND (ss_quantity <= 20)
    ), (
        SELECT avg(ss_net_paid)
        FROM store_sales
        WHERE (ss_quantity >= 1) AND (ss_quantity <= 20)
    )) AS bucket1,
    multiIf((
        SELECT count(*)
        FROM store_sales
        WHERE (ss_quantity >= 21) AND (ss_quantity <= 40)
    ) > 122840, (
        SELECT avg(ss_ext_discount_amt)
        FROM store_sales
        WHERE (ss_quantity >= 21) AND (ss_quantity <= 40)
    ), (
        SELECT avg(ss_net_paid)
        FROM store_sales
        WHERE (ss_quantity >= 21) AND (ss_quantity <= 40)
    )) AS bucket2,
    multiIf((
        SELECT count(*)
        FROM store_sales
        WHERE (ss_quantity >= 41) AND (ss_quantity <= 60)
    ) > 56580, (
        SELECT avg(ss_ext_discount_amt)
        FROM store_sales
        WHERE (ss_quantity >= 41) AND (ss_quantity <= 60)
    ), (
        SELECT avg(ss_net_paid)
        FROM store_sales
        WHERE (ss_quantity >= 41) AND (ss_quantity <= 60)
    )) AS bucket3,
    multiIf((
        SELECT count(*)
        FROM store_sales
        WHERE (ss_quantity >= 61) AND (ss_quantity <= 80)
    ) > 10097, (
        SELECT avg(ss_ext_discount_amt)
        FROM store_sales
        WHERE (ss_quantity >= 61) AND (ss_quantity <= 80)
    ), (
        SELECT avg(ss_net_paid)
        FROM store_sales
        WHERE (ss_quantity >= 61) AND (ss_quantity <= 80)
    )) AS bucket4,
    multiIf((
        SELECT count(*)
        FROM store_sales
        WHERE (ss_quantity >= 81) AND (ss_quantity <= 100)
    ) > 165306, (
        SELECT avg(ss_ext_discount_amt)
        FROM store_sales
        WHERE (ss_quantity >= 81) AND (ss_quantity <= 100)
    ), (
        SELECT avg(ss_net_paid)
        FROM store_sales
        WHERE (ss_quantity >= 81) AND (ss_quantity <= 100)
    )) AS bucket5
FROM reason
WHERE r_reason_sk = 1;