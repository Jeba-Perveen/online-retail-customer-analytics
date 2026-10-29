-- =====================================================================
-- 03_dimensions.sql
-- Builds the dimension tables of the star schema.
-- Expected: dim_product 4,739 | dim_customer 5,942 | dim_date 739
-- =====================================================================

use RetailDB;
go

-- Dimension Tables
-----------------------------------------------
-- dim_product
-----------------------------------------------
create table dim_product(ProductKey INT IDENTITY(1,1) primary key,
						 StockCode varchar(50) not null unique,
						 ProductName varchar(300));

go

insert into dim_product(StockCode,ProductName)
select distinct StockCode,Description 
from stg_retail
where row_type = 'sale';

go

-- 14 products appear only in return rows. Without them the INNER JOIN in
-- fact_returns silently dropped 21 rows (found by comparing row counts).
insert into dim_product (StockCode, ProductName)
select distinct s.StockCode, s.Description
from stg_retail s
where s.row_type = 'return'
  and not exists (select 1 from dim_product p where p.StockCode = s.StockCode)
  
select count(distinct StockCode) from dim_product  ;

go

-----------------------------------------------
-- dim_customer
-----------------------------------------------
create table dim_customer(CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
						  CustomerID int not null unique,
						  Country varchar(50));
go


with cte as(						  
	select CustomerID,
		   Country,
		   row_number() over(partition by CustomerID order by InvoiceDate desc) as rnk
	from stg_retail
	where CustomerID is not null )

insert into dim_customer(CustomerID,Country)
select CustomerID,
	   Country
from cte
where rnk = 1;

go


-----------------------------------------------
-- dim_date
-----------------------------------------------
create table dim_date (
    DateKey    int primary key,
    FullDate   date not null unique,
    [Year]     int,
    [Quarter]  int,
    [Month]    int,
    MonthName  varchar(20),
    [Day]      int,
    DayName    varchar(20),
    YearMonth  varchar(7));

go

with d as (
    select cast('2009-12-01' as date) as dt
    union all
    select dateadd(day, 1, dt) from d where dt < '2011-12-09'
)
insert into dim_date 
      (DateKey, FullDate, [Year], [Quarter], [Month], MonthName, [Day], DayName, YearMonth)
select
    year(dt) * 10000 + month(dt) * 100 + day(dt),
    dt,
    year(dt),
    datepart(quarter, dt),
    month(dt),
    datename(month, dt),
    day(dt),
    datename(weekday, dt),
    format(dt, 'yyyy-MM')
from d
option (MAXRECURSION 1000);