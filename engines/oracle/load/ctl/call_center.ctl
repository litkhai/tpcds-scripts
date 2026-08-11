LOAD DATA
INFILE	'@DATA_DIR@/call_center.dat'
BADFILE	'@LOG_DIR@/call_center.bad'
DISCARDFILE	'@LOG_DIR@/call_center.dsc'
INSERT INTO TABLE CALL_CENTER
FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
(cc_call_center_sk,cc_call_center_id,cc_rec_start_date DATE "YYYY-MM-DD",cc_rec_end_date DATE "YYYY-MM-DD",cc_closed_date_sk,cc_open_date_sk,cc_name,cc_class,cc_employees,cc_sq_ft,cc_hours,cc_manager,cc_mkt_id,cc_mkt_class,cc_mkt_desc,cc_market_manager,cc_division,cc_division_name,cc_company,cc_company_name,cc_street_number,cc_street_name,cc_street_type,cc_suite_number,cc_city, cc_county,cc_state,cc_zip,cc_country,cc_gmt_offset,cc_tax_percentage)