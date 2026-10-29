-- ====================================================================
-- 01_staging.sql
-- Creates the database and the staging layer, then loads retail_clean.csv.
-- Run order: first file of the pipeline.
-- Expected: stg_retail has 1,044,848 rows (checked in 05_validation.sql).
-- =====================================================================

create database RetailDB;
go
use RetailDB
go

drop table if exists stg_retail;
create table stg_retail(
		Invoice	VARCHAR(20),
		StockCode VARCHAR(20),
		Description	VARCHAR(500),
		Quantity INT,
		InvoiceDate	DATETIME,
		Price Decimal(10,5),
		CustomerID	INT,
		Country	VARCHAR(50),
		row_type	VARCHAR(30),
		Sales	FLOAT);
go

bulk insert stg_retail
from 'C:\Users\jebap\retail_clean.csv'
with (format = 'CSV',
	  firstrow = 2,
	  fieldterminator =',',
	  keepnulls);
go