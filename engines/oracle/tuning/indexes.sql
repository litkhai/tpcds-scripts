--
-- Oracle — optional indexes on the fact-table foreign keys.
-- Oracle — 팩트 테이블 외래키에 대한 선택적 인덱스.
--
-- TPC-DS restricts auxiliary data structures: the official rules require that any
-- index be declared in the FDR and applied uniformly, and several TPC-DS queries
-- scan enough of each fact table that a full scan beats an index range scan. Treat
-- this file as a starting point for exploring plans, not as a required step, and
-- do not compare timings taken with and without it.
-- TPC-DS 는 보조 데이터 구조를 제한합니다. 공식 규칙은 인덱스를 FDR 에 명시하고
-- 균일하게 적용하도록 요구하며, 여러 TPC-DS 쿼리는 팩트 테이블을 충분히 많이
-- 스캔하므로 인덱스 범위 스캔보다 전체 스캔이 유리합니다. 이 파일은 실행 계획을
-- 탐색하기 위한 출발점이며 필수 단계가 아닙니다. 적용 전후의 측정값을 서로
-- 비교하지 마십시오.
--
-- The primary keys declared in ddl/schema.sql already create unique indexes; what
-- follows covers the join columns those do not.
-- ddl/schema.sql 에 선언된 기본키가 이미 유니크 인덱스를 만듭니다. 아래는 기본키가
-- 다루지 않는 조인 컬럼을 보완합니다.
--
-- See / 참고: NOTICE.md, docs/reference/methodology.md
--

-- Date is the most selective dimension in almost every query, so the *_date_sk
-- columns are the ones most likely to pay for themselves.
-- 거의 모든 쿼리에서 날짜가 가장 선택도 높은 차원이므로 *_date_sk 컬럼이 효과를
-- 볼 가능성이 가장 큽니다.
create index ss_sold_date_sk_idx  on store_sales   (ss_sold_date_sk);
create index cs_sold_date_sk_idx  on catalog_sales (cs_sold_date_sk);
create index ws_sold_date_sk_idx  on web_sales     (ws_sold_date_sk);
create index sr_returned_date_idx on store_returns   (sr_returned_date_sk);
create index cr_returned_date_idx on catalog_returns (cr_returned_date_sk);
create index wr_returned_date_idx on web_returns     (wr_returned_date_sk);
create index inv_date_sk_idx      on inventory       (inv_date_sk);

-- Remaining fact-table foreign keys.
-- 나머지 팩트 테이블 외래키.
create index ss_customer_sk_idx on store_sales   (ss_customer_sk);
create index ss_store_sk_idx    on store_sales   (ss_store_sk);
create index ss_item_sk_idx     on store_sales   (ss_item_sk);
create index cs_bill_cust_idx   on catalog_sales (cs_bill_customer_sk);
create index cs_item_sk_idx     on catalog_sales (cs_item_sk);
create index ws_bill_cust_idx   on web_sales     (ws_bill_customer_sk);
create index ws_item_sk_idx     on web_sales     (ws_item_sk);
create index inv_item_sk_idx    on inventory     (inv_item_sk);
create index inv_warehouse_idx  on inventory     (inv_warehouse_sk);

-- Dimension columns used as filter predicates rather than join keys.
-- 조인 키가 아니라 필터 조건으로 쓰이는 차원 컬럼.
create index d_year_idx      on date_dim (d_year);
create index d_month_seq_idx on date_dim (d_month_seq);
create index d_date_idx      on date_dim (d_date);
create index i_category_idx  on item     (i_category);
create index c_customer_sk_addr_idx on customer (c_current_addr_sk);
