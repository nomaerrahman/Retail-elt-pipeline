-- Monthly KPIs for the dashboard's trend page.
with orders as (
    select customer_id, invoice_no, min(order_date) as order_date, sum(line_revenue) as order_revenue
    from {{ ref('fct_sales') }}
    group by 1, 2
)

select
    strftime(o.order_date, '%Y-%m')                            as year_month,
    count(*)                                                   as orders,
    count(distinct o.customer_id)                              as active_customers,
    count(distinct case when strftime(o.order_date, '%Y-%m') = c.cohort_month
                        then o.customer_id end)                as new_customers,
    cast(sum(o.order_revenue) as decimal(12, 2))               as revenue,
    cast(avg(o.order_revenue) as decimal(12, 2))               as avg_order_value
from orders o
join {{ ref('dim_customer') }} c using (customer_id)
group by 1
order by 1
