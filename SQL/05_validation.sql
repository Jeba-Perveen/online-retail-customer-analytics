-- =====================================================================
-- 05_validation.sql
-- Run after 01, 03 and 04. Every result should match the expected value.
-- =====================================================================
use RetailDB;
go

---------------staging---------------
select count(*) from stg_retail;
select count(*) from stg_retail where row_type = 'sale';
select count(*) from stg_retail where CustomerID is null;
select count(*) from stg_retail where Description is null;
select sum(sales) from stg_retail


---------------dimensions---------------
select count(*) from dim_customer;
select count(*) from dim_date;
select count(*) from dim_product;


---------------facts sales---------------
select count(*) from fact_sales;
select sum(sales) from fact_sales;
select count(distinct Invoice) from fact_sales;
select count(*) from fact_sales where CustomerKey is null;


---------------facts returns---------------
select count(*) from fact_returns;
select sum(sales) from fact_returns;
select count(distinct Invoice) from fact_returns;
select count(*) from fact_returns where CustomerKey is null;


-- ---------------- Reconciliation: fact totals must equal the staging totals ----------------
select (select sum(Sales) from fact_sales) as fact_total,
       (select sum(Sales) from stg_retail where row_type = 'sale') as staging_total;
