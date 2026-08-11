--
-- Vertica — physical design notes and statistics.
-- Vertica — 물리 설계 안내 및 통계.
--
-- Vertica has no indexes. Performance comes from projections: the sort order,
-- encoding and segmentation of the stored copy of each table. CREATE TABLE alone
-- produces a superprojection whose sort order is just the column order, which is
-- rarely what the TPC-DS joins want.
-- Vertica 에는 인덱스가 없습니다. 성능은 프로젝션, 즉 각 테이블 저장본의 정렬 순서·
-- 인코딩·세그먼테이션에서 나옵니다. CREATE TABLE 만 실행하면 컬럼 순서를 정렬 순서로
-- 갖는 슈퍼프로젝션이 생기는데, 이는 TPC-DS 조인이 원하는 형태가 아닙니다.
--
-- The supported way to design projections is Database Designer, which reads the
-- actual query set and data distribution. Hand-written projections here would be
-- guesses; running DBD against engines/vertica/queries/ produces a better design
-- than anything checked into this repository:
-- 프로젝션 설계의 정식 방법은 실제 쿼리 세트와 데이터 분포를 읽는 Database Designer
-- 입니다. 여기에 손으로 쓴 프로젝션은 추측일 뿐이며, engines/vertica/queries/ 에 대해
-- DBD 를 실행하는 것이 이 리포지토리에 담을 수 있는 어떤 설계보다 낫습니다.
--
--   admintools -t create_design -d tpcds -s comprehensive \
--     -q engines/vertica/queries -o /tmp/tpcds-design
--
-- or from SQL, via the DESIGNER_* functions:
-- 또는 SQL 에서 DESIGNER_* 함수를 사용합니다.
--
--   SELECT DESIGNER_CREATE_DESIGN('tpcds_design');
--   SELECT DESIGNER_ADD_DESIGN_TABLES('tpcds_design', 'public.*');
--   SELECT DESIGNER_ADD_DESIGN_QUERIES('tpcds_design', '/path/to/queries.sql', true);
--   SELECT DESIGNER_SET_DESIGN_TYPE('tpcds_design', 'COMPREHENSIVE');
--   SELECT DESIGNER_RUN_POPULATE_DESIGN_AND_DEPLOY('tpcds_design',
--            '/tmp/design.sql', '/tmp/deploy.sql');
--
-- See / 참고: docs/engines/vertica.md
--

-- Segmenting the large fact tables on their own primary key spreads them evenly
-- across nodes and keeps the sales/returns join local, avoiding a resegment.
-- 대형 팩트 테이블을 자체 기본키로 세그먼트하면 노드 간에 균등히 분산되고
-- 판매/반품 조인이 노드 로컬로 유지되어 resegment 를 피할 수 있습니다.
--
-- These are commented out because they are only correct for a multi-node cluster
-- and they replace the superprojection; uncomment deliberately.
-- 다중 노드 클러스터에서만 적절하고 슈퍼프로젝션을 대체하므로 주석 처리했습니다.
-- 의도적으로 해제하십시오.
--
-- CREATE PROJECTION store_sales_p (
--   ss_sold_date_sk ENCODING RLE, ss_item_sk, ss_ticket_number,
--   ss_customer_sk, ss_store_sk, ss_quantity, ss_net_paid, ss_net_profit
-- ) AS SELECT ss_sold_date_sk, ss_item_sk, ss_ticket_number,
--            ss_customer_sk, ss_store_sk, ss_quantity, ss_net_paid, ss_net_profit
--     FROM store_sales
--     ORDER BY ss_sold_date_sk, ss_item_sk
--     SEGMENTED BY HASH(ss_item_sk, ss_ticket_number) ALL NODES;
-- SELECT REFRESH('store_sales');

-- Statistics are mandatory, not optional: without them the optimiser has no
-- cardinality estimates for the fact tables and picks unusable join orders.
-- 통계는 선택이 아니라 필수입니다. 통계가 없으면 옵티마이저가 팩트 테이블
-- 카디널리티를 추정할 수 없어 사용할 수 없는 조인 순서를 선택합니다.
SELECT ANALYZE_STATISTICS('');

-- Report any projection the optimiser still considers unanalysed.
-- 옵티마이저가 아직 미분석으로 보는 프로젝션을 보고합니다.
SELECT anchor_table_name, projection_name, has_statistics
FROM   v_catalog.projections
WHERE  NOT has_statistics
ORDER  BY anchor_table_name, projection_name;
