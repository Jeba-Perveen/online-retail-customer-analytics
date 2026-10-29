-- =====================================================================
-- 04_facts.sql
-- Builds the fact tables.
-- Expected: fact_sales 1,015,088 rows | fact_returns 17,974 rows
-- =====================================================================

use RetailDB;

go

-- ---------------------------------------------------------------------
-- fact_sales  (row_type = 'sale')
-- CustomerKey is NULL for the 226,882 rows that have no Customer ID, hence LEFT JOIN.
-- SalesKey is a surrogate key because Invoice + StockCode is not unique
-- (11,812 exact duplicates inside a single sheet were kept).
-- ---------------------------------------------------------------------
create table fact_sales(SalesKey bigint identity(1,1) primary key,
                        Invoice	varchar(20) not null,
                        ProductKey	int not null references dim_product(ProductKey) ,
                        CustomerKey	int null references dim_customer(CustomerKey),
                        DateKey	int not null references dim_date(DateKey),
                        InvoiceDateTime	datetime not null,
                        Country	varchar(50),
                        Quantity int,
                        Price decimal(12,5),
                        Sales decimal(18,5));

go
                        

INSERT INTO fact_sales
    (Invoice, ProductKey, CustomerKey, DateKey, InvoiceDateTime, Country, Quantity, Price, Sales)
SELECT s.Invoice, p.ProductKey, c.CustomerKey, d.DateKey, s.InvoiceDate, s.Country, s.Quantity,
       CAST(s.Price AS DECIMAL(12,5)),
       CAST(s.Price AS DECIMAL(12,5))*s.Quantity
FROM stg_retail s
INNER JOIN dim_product  p ON s.StockCode = p.StockCode
LEFT  JOIN dim_customer c ON s.CustomerID = c.CustomerID
INNER JOIN dim_date     d ON d.FullDate = CAST(s.InvoiceDate AS DATE)
WHERE s.row_type = 'sale';

go


-- ---------------------------------------------------------------------
-- fact_returns  (row_type = 'return'; Quantity and Sales are negative)
-- ---------------------------------------------------------------------
create table fact_returns(ReturnKey bigint identity(1,1) primary key,
                        Invoice	varchar(20) not null,
                        ProductKey	int not null references dim_product(ProductKey) ,
                        CustomerKey	int null references dim_customer(CustomerKey),
                        DateKey	int not null references dim_date(DateKey),
                        InvoiceDateTime	datetime not null,
                        Country	varchar(50),
                        Quantity int,
                        Price decimal(12,5),
                        Sales decimal(18,5));
 
go


INSERT INTO fact_returns
    (Invoice, ProductKey, CustomerKey, DateKey, InvoiceDateTime, Country, Quantity, Price, Sales)
SELECT s.Invoice, p.ProductKey, c.CustomerKey, d.DateKey, s.InvoiceDate, s.Country, s.Quantity,
       CAST(s.Price AS DECIMAL(12,5)),
       CAST(s.Price AS DECIMAL(12,5))*s.Quantity
FROM stg_retail s
INNER JOIN dim_product  p ON s.StockCode = p.StockCode
LEFT  JOIN dim_customer c ON s.CustomerID = c.CustomerID
INNER JOIN dim_date     d ON d.FullDate = CAST(s.InvoiceDate AS DATE)
WHERE s.row_type = 'return';

go