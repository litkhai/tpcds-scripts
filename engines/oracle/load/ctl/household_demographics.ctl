LOAD DATA
INFILE	'@DATA_DIR@/household_demographics.dat'
BADFILE	'@LOG_DIR@/household_demographics.bad'
DISCARDFILE	'@LOG_DIR@/household_demographics.dsc'
INSERT INTO TABLE HOUSEHOLD_DEMOGRAPHICS
FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
(hd_demo_sk,hd_income_band_sk,hd_buy_potential,hd_dep_count,hd_vehicle_count	)

