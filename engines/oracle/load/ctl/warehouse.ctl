LOAD DATA
INFILE	'@DATA_DIR@/warehouse.dat'
BADFILE	'@LOG_DIR@/warehouse.bad'
DISCARDFILE	'@LOG_DIR@/warehouse.dsc'
INSERT INTO TABLE WAREHOUSE
FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
(w_warehouse_sk,w_warehouse_id,w_warehouse_name,w_warehouse_sq_ft,w_street_number,w_street_name,w_street_type,w_suite_number,w_city,w_county,w_state,w_zip,w_country,w_gmt_offset	)
