-- Share of each monthly acquisition cohort that ordered again N months later.
with activity as (
    select distinct
        s.customer_id,
        c.cohort_month,
        strftime(s.order_date, '%Y-%m') as active_month
    from {{ ref('fct_sales') }} s
    join {{ ref('dim_customer') }} c using (customer_id)
),

indexed as (
    select
        *,
        date_diff('month', strptime(cohort_month, '%Y-%m'), strptime(active_month, '%Y-%m')) as months_since_first
    from activity
),

cohort_size as (
    select cohort_month, count(*) as cohort_customers
    from {{ ref('dim_customer') }}
    group by 1
)

select
    i.cohort_month,
    i.months_since_first,
    cs.cohort_customers,
    count(distinct i.customer_id)                                       as active_customers,
    round(count(distinct i.customer_id) / cs.cohort_customers, 4)       as retention_rate
from indexed i
join cohort_size cs using (cohort_month)
group by 1, 2, 3
order by 1, 2
