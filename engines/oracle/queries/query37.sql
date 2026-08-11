/* **** 37 */
select * from (select i_item_id
    ,i_item_desc
    ,i_current_price
 from item, inventory, date_dim, catalog_sales
 where i_current_price between 45 and 45 + 30
 and inv_item_sk = i_item_sk
 and d_date_sk=inv_date_sk
 and d_date between to_date('1999-02-21', 'YYYY-MM-DD') and (to_date('1999-02-21', 'YYYY-MM-DD') + 60)
 and i_manufact_id in (856,707,1000,747)
 and inv_quantity_on_hand between 100 and 500
 and cs_item_sk = i_item_sk
 group by i_item_id,i_item_desc,i_current_price
 order by i_item_id
 ) where rownum <= 100;