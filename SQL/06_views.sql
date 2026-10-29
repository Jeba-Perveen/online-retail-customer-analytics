-- =====================================================================
-- 06_views.sql
-- Reporting views built on top of the star schema.
-- Dependency chain:
--   vw_sales_detail
--   vw_customer_revenue -> vw_customer_rfm -> vw_customer_rfm_scores -> vw_customer_segments
-- =====================================================================

use RetailDB;

go

-- ---------------------------------------------------------------------
-- vw_sales_detail
-- Business use: one flat, readable view of every sale line (facts + dimensions),
-- so later queries do not repeat the same three joins.
-- Grain: one row per sale line.
-- Expected: 1,015,088 rows | SUM(Sales) about 19,700,954.457
-- ---------------------------------------------------------------------

create or alter view vw_sales_detail as
	select s.SalesKey, 
		   s.Invoice, 
		   s.InvoiceDateTime,
		   d.FullDate, 
		   d.[Year], 
		   d.[Quarter],
		   d.[Month], 
		   d.YearMonth,
		   p.StockCode, 
		   p.ProductName,
		   c.CustomerID,
		   s.Country, 
		   s.Quantity, 
		   s.Price, 
		   s.Sales
	from fact_sales s left join dim_customer  c on s.CustomerKey=c.CustomerKey
	join dim_product p on p.ProductKey = s.ProductKey
	join dim_date d on d.DateKey = s.DateKey;

go

-- ---------------------------------------------------------------------
-- vw_customer_revenue
-- Business question (A): who brings the revenue?
-- Net revenue = sales + returns (returns are stored as negative amounts), so an order that
-- was later cancelled (for example customer 12346: gross 77,352.96, net 169.36) does not
-- inflate a customer's ranking.
-- Each side is aggregated BEFORE joining, so the join cannot multiply rows (fan-out).
-- Grain: one row per customer.
-- Expected: 5,942 rows | gross 17,124,941.00 | returns -713,046.25 | net 16,411,894.75
--           110 customers with net_revenue <= 0
-- ---------------------------------------------------------------------

create or alter view vw_customer_revenue as
with gross as(
	select CustomerKey,sum(Sales) as gross_rev
	from fact_sales
	where CustomerKey is not null
	group by CustomerKey),

rets as(
	select CustomerKey,sum(Sales) as return_rev
	from fact_returns
	where CustomerKey is not null
	group by CustomerKey)

select c.CustomerKey,
	   c.CustomerID,
	   c.Country,
	   isnull(g.gross_rev,0) as gross_rev,
	   isnull(r.return_rev,0) as return_rev,
	   isnull(g.gross_rev,0)+isnull(r.return_rev,0) as net_revenue

from dim_customer c left join gross g on c.CustomerKey = g.CustomerKey 
					left join rets r on r.CustomerKey = c.CustomerKey;


go 


-- ---------------------------------------------------------------------
-- vw_customer_rfm
-- Business question (B): who is drifting away?
-- Recency   = days from the last purchase to the snapshot date.
-- Frequency = number of distinct invoices.
-- Monetary  = net revenue.
-- Snapshot date = last date in the data + 1 (10 Dec 2011); the real "today" would make
-- every customer look lost.
-- Only active customers (net_revenue > 0).
-- Grain: one row per active customer.
-- Expected: 5,832 rows | recency 1 to 739 | SUM(frequency) 36,573
-- ---------------------------------------------------------------------

create or alter view vw_customer_rfm as
with purchases as(
	select CustomerID,
		   max(FullDate) as last_purchase,
		   count(distinct Invoice) as frequency
	from vw_sales_detail 
	where CustomerID is not null
	group by CustomerID),

snap as(select dateadd(day,1, max(FullDate)) as snapshot_date from vw_sales_detail) 

select c.CustomerKey,
	   c.CustomerID,
	   datediff(day,p.last_purchase,s.snapshot_date) as recency_days,
	   p.frequency,
	   c.net_revenue as monetary
from vw_customer_revenue c join purchases p on p.CustomerID = c.CustomerID
cross join snap s
where net_revenue>0

go

-- ---------------------------------------------------------------------
-- vw_customer_rfm_scores
-- Scores from 1 (worst) to 5 (best).
-- Recency and frequency use fixed business bins, because both have many ties
-- (1,599 customers bought only once) and NTILE would give identical customers different scores.
-- Monetary is continuous, so quintiles (NTILE) are fine; CustomerKey breaks ties.
-- Expected: r_score 1/2/3/4/5 = 1,580 / 789 / 586 / 1,252 / 1,625
--           f_score 1/2/3/4/5 = 1,599 / 944 / 1,148 / 1,180 / 961
--           m_score: 1,166 or 1,167 customers per score
-- ---------------------------------------------------------------------
create or alter view vw_customer_rfm_scores as
select CustomerKey,
       CustomerID,
       recency_days,
       frequency,
       monetary,
       case when recency_days <= 30  then 5
            when recency_days <= 90  then 4
            when recency_days <= 180 then 3
            when recency_days <= 365 then 2
            ELSE 1 END AS r_score,
       case when frequency = 1  then 1
            when frequency = 2  then 2
            when frequency <= 4 then 3
            when frequency <= 9 then 4
            else 5 end as f_score,
       ntile(5) over (order by monetary, CustomerKey) as m_score
FROM vw_customer_rfm;
GO


-- ---------------------------------------------------------------------
-- vw_customer_segments
-- Business questions (B) and (C): who is at churn risk and how much revenue is at risk?
-- Churn threshold = 148 days = 90th percentile of the gap between purchases
-- (see 07_analysis.sql, section 6). A customer silent for longer than that is outside
-- the normal buying rhythm. "High value" = m_score >= 4 (top 2,332 customers by net revenue).
-- CASE is evaluated top to bottom, so each branch only sees what the earlier ones left.
-- Expected: Active - high value 1,870 | Active - standard 1,393 | At risk - high value 462
--           At risk - repeat buyer 965 | At risk - one time buyers 1,142 | total 5,832
-- ---------------------------------------------------------------------
create or alter view vw_customer_segments as
with cfg as (
			  select 148 as churn_days)
select r.CustomerKey, 
	   r.CustomerID, 
	   r.recency_days, 
	   r.frequency, 
	   r.monetary, 
	   r.m_score,
	   case when r.recency_days <= c.churn_days and r.m_score >= 4 then 'Active - high value'
		    when r.recency_days <= c.churn_days  then 'Active - standard'
			when r.m_score >= 4 then 'At risk - high value'
			when r.frequency >= 2 then 'At risk - repeat buyer'
			else 'At risk - one time buyers'
		end as Segment
from vw_customer_rfm_scores r
cross join cfg c

