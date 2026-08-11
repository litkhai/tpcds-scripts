-- TPC-DS query 33 — PostgreSQL
--
-- Upstream / 상류 출처: StarRocks/starrocks @ 9d288306166d
--   fe/fe-core/src/test/resources/sql/tpcds/query33.sql
--   License / 라이선스: Apache-2.0
-- Adaptation / 변환: date_add(cast('d' as date), n) -> (cast('d' as date) \+/- n); ORDER BY alias 'lochierarchy' expanded to its defining expression (q36/q70/q86)
--
-- TPC-DS is a trademark of the Transaction Processing Performance Council.
-- This is a TPC-DS derived workload, not an audited TPC benchmark result.
-- figures produced with it are not comparable to published TPC-DS results.
-- TPC-DS는 TPC의 상표입니다. 본 파일은 TPC-DS 파생 워크로드이며 공인된 TPC
-- 벤치마크 결과가 아닙니다. 측정값은 공표된 TPC-DS 결과와 비교할 수 없습니다.
--
-- query 33
with ss as (
 select
          i_manufact_id,sum(ss_ext_sales_price) total_sales
 from
 	store_sales,
 	date_dim,
         customer_address,
         item
 where
         i_manufact_id in (select
  i_manufact_id
from
 item
where i_category in ('Electronics'))
 and     ss_item_sk              = i_item_sk
 and     ss_sold_date_sk         = d_date_sk
 and     d_year                  = 1998
 and     d_moy                   = 5
 and     ss_addr_sk              = ca_address_sk
 and     ca_gmt_offset           = -5 
 group by i_manufact_id),
 cs as (
 select
          i_manufact_id,sum(cs_ext_sales_price) total_sales
 from
 	catalog_sales,
 	date_dim,
         customer_address,
         item
 where
         i_manufact_id               in (select
  i_manufact_id
from
 item
where i_category in ('Electronics'))
 and     cs_item_sk              = i_item_sk
 and     cs_sold_date_sk         = d_date_sk
 and     d_year                  = 1998
 and     d_moy                   = 5
 and     cs_bill_addr_sk         = ca_address_sk
 and     ca_gmt_offset           = -5 
 group by i_manufact_id),
 ws as (
 select
          i_manufact_id,sum(ws_ext_sales_price) total_sales
 from
 	web_sales,
 	date_dim,
         customer_address,
         item
 where
         i_manufact_id               in (select
  i_manufact_id
from
 item
where i_category in ('Electronics'))
 and     ws_item_sk              = i_item_sk
 and     ws_sold_date_sk         = d_date_sk
 and     d_year                  = 1998
 and     d_moy                   = 5
 and     ws_bill_addr_sk         = ca_address_sk
 and     ca_gmt_offset           = -5
 group by i_manufact_id)
  select  i_manufact_id ,sum(total_sales) total_sales
 from  (select * from ss 
        union all
        select * from cs 
        union all
        select * from ws) tmp1
 group by i_manufact_id
 order by total_sales
limit 100;


