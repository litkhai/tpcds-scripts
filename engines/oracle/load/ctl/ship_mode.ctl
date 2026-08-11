LOAD DATA
INFILE	'@DATA_DIR@/ship_mode.dat'
BADFILE	'@LOG_DIR@/ship_mode.bad'
DISCARDFILE	'@LOG_DIR@/ship_mode.dsc'
INSERT INTO TABLE SHIP_MODE
FIELDS TERMINATED BY "|" OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
(sm_ship_mode_sk,sm_ship_mode_id,sm_type,sm_code,sm_carrier,sm_contract	)
