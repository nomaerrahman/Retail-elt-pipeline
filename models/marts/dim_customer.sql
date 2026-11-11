-- One row per customer with lifetime metrics and RFM segmentation.
-- Recency is measured from the day after the last order in the dataset.
with orders as (
    select
        customer_id,
        invoice_no,
        min(order_date)   as order_date,
        sum(line_revenue) as order_revenue
    from {{ ref('fct_sales') }}
    group by 1, 2
),

customer as (
    select
        customer_id,
        min(order_date)              as first_order_date,
        max(order_date)              as last_order_date,
        count(*)                     as orders,
        sum(order_revenue)           as revenue,
        avg(order_revenue)           as avg_order_value
    from orders
    group by 1
),

country as (
    select customer_id, mode(country) as country
    from {{ ref('fct_sales') }}
    group by 1
),

scored as (
    select
        c.*,
        date_diff('day', c.last_order_date, (select max(order_date) from orders) + 1) as recency_days,
        ntile(5) over (order by date_diff('day', c.last_order_date, (select max(order_date) from orders) + 1) desc) as r_score,
        ntile(5) over (order by c.orders) as f_score,
        ntile(5) over (order by c.revenue) as m_score
    from customer c
)

select
    s.customer_id,
    co.country,
    s.first_order_date,
    s.last_order_date,
    s.orders,
    cast(s.revenue as decimal(12, 2))          as revenue,
    cast(s.avg_order_value as decimal(12, 2))  as avg_order_value,
    s.recency_days,
    s.r_score,
    s.f_score,
    s.m_score,
    case
        when s.r_score >= 4 and s.f_score >= 4 and s.m_score >= 4 then 'Champions'
        when s.r_score >= 3 and s.f_score >= 3                     then 'Loyal'
        when s.r_score >= 4 and s.f_score <= 2                     then 'New or Promising'
        when s.r_score <= 2 and s.f_score >= 3                     then 'At Risk'
        when s.r_score <= 2 and s.f_score <= 2                     then 'Lost'
        else 'Needs Attention'
    end                                         as rfm_segment,
    strftime(s.first_order_date, '%Y-%m')       as cohort_month
from scored s
left join country co using (customer_id)
