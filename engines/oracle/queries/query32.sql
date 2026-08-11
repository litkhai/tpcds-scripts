/* **** 32 */
select * from (select sum(cs_ext_discount_amt) as "excess discount amount"
from
  catalog_sales
  ,item
  ,date_dim
where
i_manufact_id = 29
and i_item_sk = cs_item_sk
and d_date between '1999-01-07' and
    (to_date('1999-01-07', 'YYYY-MM-DD') + 90)
and d_date_sk = cs_sold_date_sk
and cs_ext_discount_amt
   > (
     select
      1.3 * avg(cs_ext_discount_amt)
     from
      catalog_sales
      ,date_dim
     where
       cs_item_sk = i_item_sk
     and d_date between '1999-01-07' and
               (to_date('1999-01-07', 'YYYY-MM-DD') + 90)
     and d_date_sk = cs_sold_date_sk
   )
 ) where rownum <= 100;