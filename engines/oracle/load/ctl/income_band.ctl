LOAD DATA
INFILE	'@DATA_DIR@/income_band.dat'
BADFILE	'@LOG_DIR@/income_band.bad'
DISCARDFILE	'@LOG_DIR@/income_band.dsc'
INSERT INTO TABLE INCOME_BAND
FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
(ib_income_band_sk,ib_lower_bound,ib_upper_bound	)