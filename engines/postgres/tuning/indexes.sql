--
-- PostgreSQL — optional indexes on the fact-table foreign keys.
-- PostgreSQL — 팩트 테이블 외래키에 대한 선택적 인덱스.
--
-- TPC-DS restricts auxiliary data structures, and most TPC-DS queries touch a large
-- fraction of each fact table, where a parallel sequential scan beats an index scan.
-- Use this to explore plans, not as a required step, and do not compare timings
-- taken with and without it.
-- TPC-DS 는 보조 데이터 구조를 제한하며, 대부분의 TPC-DS 쿼리는 팩트 테이블의 큰
-- 비중을 읽으므로 병렬 순차 스캔이 인덱스 스캔보다 유리합니다. 실행 계획 탐색용이며
-- 필수 단계가 아닙니다. 적용 전후의 측정값을 서로 비교하지 마십시오.
--
-- Statistics, by contrast, are mandatory — see load/load.sh, which runs ANALYZE.
-- 반면 통계는 필수입니다. ANALYZE 를 수행하는 load/load.sh 를 참고하십시오.
--
-- See / 참고: NOTICE.md, docs/methodology.md
--

create index if not exists ss_sold_date_sk_idx  on store_sales     (ss_sold_date_sk);
create index if not exists cs_sold_date_sk_idx  on catalog_sales   (cs_sold_date_sk);
create index if not exists ws_sold_date_sk_idx  on web_sales       (ws_sold_date_sk);
create index if not exists sr_returned_date_idx on store_returns   (sr_returned_date_sk);
create index if not exists cr_returned_date_idx on catalog_returns (cr_returned_date_sk);
create index if not exists wr_returned_date_idx on web_returns     (wr_returned_date_sk);
create index if not exists inv_date_sk_idx      on inventory       (inv_date_sk);

create index if not exists ss_customer_sk_idx on store_sales   (ss_customer_sk);
create index if not exists ss_store_sk_idx    on store_sales   (ss_store_sk);
create index if not exists ss_item_sk_idx     on store_sales   (ss_item_sk);
create index if not exists cs_bill_cust_idx   on catalog_sales (cs_bill_customer_sk);
create index if not exists cs_item_sk_idx     on catalog_sales (cs_item_sk);
create index if not exists ws_bill_cust_idx   on web_sales     (ws_bill_customer_sk);
create index if not exists ws_item_sk_idx     on web_sales     (ws_item_sk);
create index if not exists inv_item_sk_idx    on inventory     (inv_item_sk);
create index if not exists inv_warehouse_idx  on inventory     (inv_warehouse_sk);

create index if not exists d_year_idx      on date_dim (d_year);
create index if not exists d_month_seq_idx on date_dim (d_month_seq);
create index if not exists d_date_idx      on date_dim (d_date);
create index if not exists i_category_idx  on item     (i_category);

-- Indexes are only used once the planner knows their selectivity.
-- 플래너가 선택도를 알아야 인덱스가 실제로 사용됩니다.
analyze;
