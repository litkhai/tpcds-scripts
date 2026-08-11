-- TPC-DS query 54 — PostgreSQL
--
-- Upstream / 상류 출처: StarRocks/starrocks @ 9d288306166d
--   fe/fe-core/src/test/resources/sql/tpcds/query54.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: date_add(cast('d' as date), n) -> (cast('d' as date) \+/- n); ORDER BY alias 'lochierarchy' expanded to its defining expression (q36/q70/q86)
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
-- query 54
with my_customers as (
 select distinct c_customer_sk
        , c_current_addr_sk
 from   
        ( select cs_sold_date_sk sold_date_sk,
                 cs_bill_customer_sk customer_sk,
                 cs_item_sk item_sk
          from   catalog_sales
          union all
          select ws_sold_date_sk sold_date_sk,
                 ws_bill_customer_sk customer_sk,
                 ws_item_sk item_sk
          from   web_sales
         ) cs_or_ws_sales,
         item,
         date_dim,
         customer
 where   sold_date_sk = d_date_sk
         and item_sk = i_item_sk
         and i_category = 'Women'
         and i_class = 'maternity'
         and c_customer_sk = cs_or_ws_sales.customer_sk
         and d_moy = 12
         and d_year = 1998
 )
 , my_revenue as (
 select c_customer_sk,
        sum(ss_ext_sales_price) as revenue
 from   my_customers,
        store_sales,
        customer_address,
        store,
        date_dim
 where  c_current_addr_sk = ca_address_sk
        and ca_county = s_county
        and ca_state = s_state
        and ss_sold_date_sk = d_date_sk
        and c_customer_sk = ss_customer_sk
        and d_month_seq between (select distinct d_month_seq+1
                                 from   date_dim where d_year = 1998 and d_moy = 12)
                           and  (select distinct d_month_seq+3
                                 from   date_dim where d_year = 1998 and d_moy = 12)
 group by c_customer_sk
 )
 , segments as
 (select cast((revenue/50) as int) as segment
  from   my_revenue
 )
  select  segment, count(*) as num_customers, segment*50 as segment_base
 from segments
 group by segment
 order by segment, num_customers
 limit 100;


