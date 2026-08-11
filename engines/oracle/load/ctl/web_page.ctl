LOAD DATA
INFILE	'@DATA_DIR@/web_page.dat'
BADFILE	'@LOG_DIR@/web_page.bad'
DISCARDFILE	'@LOG_DIR@/web_page.dsc'
INSERT INTO TABLE WEB_PAGE
FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
(wp_web_page_sk,wp_web_page_id,wp_rec_start_date DATE "YYYY-MM-DD",wp_rec_end_date DATE "YYYY-MM-DD",wp_creation_date_sk,wp_access_date_sk,wp_autogen_flag,wp_customer_sk,wp_url,wp_type,wp_char_count,wp_link_count,wp_image_count,wp_max_ad_count	)
