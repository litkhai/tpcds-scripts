LOAD DATA
INFILE	'@DATA_DIR@/customer_demographics.dat'
BADFILE	'@LOG_DIR@/customer_demographics.bad'
DISCARDFILE	'@LOG_DIR@/customer_demographics.dsc'
INSERT INTO TABLE CUSTOMER_DEMOGRAPHICS
FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
(cd_demo_sk,cd_gender,cd_marital_status,cd_education_status,cd_purchase_estimate,cd_credit_rating,cd_dep_count,cd_dep_employed_count,cd_dep_college_count	)
