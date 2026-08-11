LOAD DATA
INFILE	'@DATA_DIR@/item.dat'
BADFILE	'@LOG_DIR@/item.bad'
DISCARDFILE	'@LOG_DIR@/item.dsc'
INSERT INTO TABLE ITEM
FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
(i_item_sk,i_item_id,i_rec_start_date DATE "YYYY-MM-DD",i_rec_end_date DATE "YYYY-MM-DD",i_item_desc,i_current_price,i_wholesale_cost,i_brand_id,i_brand,i_class_id,i_class,i_category_id,i_category,i_manufact_id,i_manufact,i_size,i_formulation,i_color,i_units,i_container,i_manager_id,i_product_name	)
