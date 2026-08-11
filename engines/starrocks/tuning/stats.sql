--
-- StarRocks — statistics and session settings.
-- StarRocks — 통계 및 세션 설정.
--
-- StarRocks has no secondary indexes to create. The physical design is already in
-- ddl/schema.sql as the DUPLICATE KEY (sort order) and DISTRIBUTED BY HASH
-- (bucketing) clauses that came with the upstream schema.
-- StarRocks 에는 생성할 보조 인덱스가 없습니다. 물리 설계는 상류 스키마에 포함된
-- DUPLICATE KEY(정렬 순서)와 DISTRIBUTED BY HASH(버킷팅) 절로 이미
-- ddl/schema.sql 에 들어 있습니다.
--
-- The upstream schema hardcodes `buckets 192`, which suits a large cluster. On a
-- single BE that over-partitions the data; StarRocks 3.x can choose for itself if
-- the clause is removed, or set it to roughly (BE count x cores) / 2.
-- 상류 스키마는 `buckets 192` 를 고정하고 있어 대규모 클러스터에 적합합니다. 단일
-- BE 에서는 과도한 분할이 되므로, 절을 제거해 StarRocks 3.x 가 자동으로 정하게 하거나
-- 대략 (BE 수 x 코어 수) / 2 로 설정하십시오.
--
-- See / 참고: docs/engines/starrocks.md
--

-- Full statistics on every table. StarRocks also collects automatically, but an
-- explicit pass after a bulk load stops the first queries planning against stale
-- estimates.
-- 모든 테이블에 대한 전체 통계. StarRocks 는 자동 수집도 하지만, 벌크 적재 후
-- 명시적으로 수집하면 첫 쿼리들이 오래된 추정치로 계획되는 것을 막습니다.
ANALYZE TABLE call_center;
ANALYZE TABLE catalog_page;
ANALYZE TABLE catalog_returns;
ANALYZE TABLE catalog_sales;
ANALYZE TABLE customer;
ANALYZE TABLE customer_address;
ANALYZE TABLE customer_demographics;
ANALYZE TABLE date_dim;
ANALYZE TABLE household_demographics;
ANALYZE TABLE income_band;
ANALYZE TABLE inventory;
ANALYZE TABLE item;
ANALYZE TABLE promotion;
ANALYZE TABLE reason;
ANALYZE TABLE ship_mode;
ANALYZE TABLE store;
ANALYZE TABLE store_returns;
ANALYZE TABLE store_sales;
ANALYZE TABLE time_dim;
ANALYZE TABLE warehouse;
ANALYZE TABLE web_page;
ANALYZE TABLE web_returns;
ANALYZE TABLE web_sales;
ANALYZE TABLE web_site;

-- Confirm statistics landed. An empty result means none were collected.
-- 통계 수집 여부를 확인합니다. 결과가 비어 있으면 수집되지 않은 것입니다.
SHOW ANALYZE STATUS;
