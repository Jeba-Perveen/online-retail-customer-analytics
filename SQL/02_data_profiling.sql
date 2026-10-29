-- =====================================================================
-- 02_data_profiling.sql
-- Read-only exploration queries that decided the table design.
-- Run order: after 01_staging.sql. Nothing here changes data.
-- =====================================================================

use RetailDB;
go

/*
 1) Size of the sale rows
 Expected: 1,015,088 rows | 39,516 invoices | 5,852 customers
           4,725 StockCodes | 43 countries | 226,882 rows without CustomerID */

select count(*) as total_row,
	   count(distinct Invoice) as total_invoice,
	   count(distinct StockCode) as total_stockcode ,
	   sum(case when CustomerID is null then 1 else 0 end) as null_customer_rows,
	   count(distinct Country) as total_country,
	   count(distinct CustomerID) as total_customers
from stg_retail
where row_type = 'sale'


-- 2) Case-sensitive StockCode count (should match the case-insensitive one now)
-- Expected: 4,725
select count(distinct StockCode collate Latin1_General_CS_AS)
from stg_retail
where row_type = 'sale';


-- 3) Customers with more than one Country (sale rows only)
-- Expected: 12
with cte as(
select CustomerID
from stg_retail
where row_type = 'sale' and CustomerID is not null
group by CustomerID
having count(distinct Country) > 1)

select count(*) from cte;


-- 4) Invoices with more than one distinct InvoiceDate
-- Expected: 82 

with cte as(
select Invoice
from stg_retail
where row_type = 'sale' 
group by Invoice
having count(distinct InvoiceDate) > 1)

select count(*) from cte;


-- 5) Invoices with more than one customer
-- Expected: 0
with multi as (
    select Invoice
    from stg_retail
    where row_type = 'sale' and CustomerID is not null
    group by Invoice
    having count(distinct CustomerID) > 1
)
select count(*) from multi;


-- 6) Invoices with more than one country
-- Expected: 0

with multi as (
    select Invoice
    from stg_retail
    where row_type = 'sale' and CustomerID is not null
    group by Invoice
    having count(distinct Country) > 1
)
select count(*) from multi;


-- 7) StockCodes with more than one Description (sale rows)
-- Expected: no rows
select StockCode 
from stg_retail
where row_type = 'sale'
group by StockCode 
having count(distinct Description) > 1 