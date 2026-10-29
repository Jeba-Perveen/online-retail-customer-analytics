-- =====================================================================
-- 07_analysis.sql
-- Business problem: which customers bring the revenue, who is likely to churn,
-- and how much revenue is at risk?
-- =====================================================================
use RetailDB;
go 

-- ---------------------------------------------------------------------
-- 1) Monthly gross revenue and month-over-month growth
-- ---------------------------------------------------------------------
with cte as(
	select YearMonth,
		   sum(sales) as gross_revenue ,
		   min(FullDate) as min_date,
		   max(FullDate) as max_date
	from vw_sales_detail
	group by YearMonth),

cte2 as(
select YearMonth,
	   max_date,
	   gross_revenue,
	   lag(gross_revenue) over (order BY YearMonth) as prev_revenue
from cte
)
select YearMonth,
	   max_date,
	   gross_revenue,
	   round(100*(gross_revenue-prev_revenue)/prev_revenue,2) as MoM,
	   case when YearMonth = (select max(YearMonth) from cte)
			and max_date < eomonth(max_date) then 1 else 0 end as is_partial
from cte2 
order by YearMonth;


-- ---------------------------------------------------------------------
-- 2) Gross, returns, net revenue and return rate by month
-- ---------------------------------------------------------------------
with gross as (
    select YearMonth, sum(Sales) as gross_revenue
    from vw_sales_detail
    group by YearMonth
),
rets as (
    select d.YearMonth, sum(r.Sales) as return_amount
    from fact_returns r
    join dim_date d on d.DateKey = r.DateKey
    group by d.YearMonth
)
select g.YearMonth,
       g.gross_revenue,
       isnull(r.return_amount, 0) as return_amount,
       g.gross_revenue + isnull(r.return_amount, 0) as net_revenue,
       round(-isnull(r.return_amount, 0) / g.gross_revenue * 100, 2) as return_rate
from gross g
left join rets r on r.YearMonth = g.YearMonth
order by g.YearMonth;


-- ---------------------------------------------------------------------
-- 3) Customer revenue checks (vw_customer_revenue)
-- ---------------------------------------------------------------------
select count(*) as total_count,
	   sum(gross_rev) as gross_revenue,
	   sum(return_rev) as return_revenue,
	   sum(net_revenue) as net_revenue,
	   sum(case when net_revenue <=0 then 1 else 0 end) as customers_with_no_net_revenue
from vw_customer_revenue;


-- ---------------------------------------------------------------------
-- 4) Revenue concentration (Pareto) by decile of active customers
-- Business question (A): how much of the revenue do the top customers bring?
-- ---------------------------------------------------------------------
with active as(
	select *
	from vw_customer_revenue
	where net_revenue>0),

ranked as (
	select *,ntile(10) over(order by net_revenue desc,CustomerKey) as decile
	from active),

decile_rev as(
	select decile,
		   count(*) as customer,
		   sum(net_revenue) as revenue
	from ranked
	group by decile)

select decile,
	   customer,
	   revenue,
	   round(revenue * 100.0/sum(revenue) over(),2) as share_pct,
	   round(sum(revenue) over(order by decile rows between unbounded preceding and current row)*100.0/sum(revenue) over(),2) as cum_share_pct
from decile_rev
order by decile;


-- ---------------------------------------------------------------------
-- 5) Why recency and frequency use fixed bins instead of NTILE
-- ---------------------------------------------------------------------
with scored as (
select frequency,
	   ntile(5) over(order by frequency) as f_score
from vw_customer_rfm)

select f_score,count(*) as customers
from scored
where frequency=1
group by f_score
order by f_score;


-- RFM score checks
select r_score,
	   count(*) as customers 
from vw_customer_rfm_scores
group by r_score 
order by r_score;


select f_score, 
	   count(*) as customers 
from vw_customer_rfm_scores 
group by f_score 
order by f_score;



select m_score, 
	   count(*) as customers 
from vw_customer_rfm_scores 
group by m_score 
order BY m_score;

select * from vw_customer_rfm_scores 
where CustomerID in (18102, 14646, 12346);

select count(*) 
from vw_customer_rfm_scores 
where r_score = 5 and f_score = 5;


-- ---------------------------------------------------------------------
-- 6) Data-driven churn threshold: the gap between a customer's consecutive purchase days
-- A customer silent for longer than the 90th percentile gap is outside the normal rhythm.
-- ---------------------------------------------------------------------
with purchase_days as (
    select distinct s.CustomerID, s.FullDate
    from vw_sales_detail s
    join vw_customer_rfm r on r.CustomerID = s.CustomerID
),
gaps as (
    select CustomerID,
           datediff(day,
                    lag(FullDate) over (partition by CustomerID order by FullDate),
                    FullDate) as gap_days
    from purchase_days
)

select distinct
       PERCENTILE_CONT(0.5)  within group (order by gap_days) over () as median_gap,
       PERCENTILE_CONT(0.75) within group (order by gap_days) over () as p75_gap,
       PERCENTILE_CONT(0.9)  within group (order by gap_days) over () as p90_gap,
       PERCENTILE_CONT(0.95) within group (order by gap_days) over () as p95_gap,
       AVG(CAST(gap_days as float)) over ()                           as mean_gap
from gaps
where gap_days is not null;


-- ---------------------------------------------------------------------
-- 7) Segments and revenue at risk
-- ---------------------------------------------------------------------
select segment,
       count(*) as customers,
       sum(monetary) AS revenue,
       round(sum(monetary) * 100.0 / sum(sum(monetary)) over (), 2) as revenue_share_pct
from vw_customer_segments
group by segment
order by revenue desc;

---------------------------------------------------------------------------
-- Total revenue at risk (all "At risk" segments together)
---------------------------------------------------------------------------
select count(*)  as customers_at_risk,
       sum(monetary) as revenue_at_risk,
       round(sum(monetary) * 100.0 / (select sum(monetary) from vw_customer_segments), 2) as share_of_net_revenue_pct
from vw_customer_segments
where segment LIKE 'At risk%';

go