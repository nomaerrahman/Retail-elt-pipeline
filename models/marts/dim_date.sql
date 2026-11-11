-- Calendar dimension covering the full sales period.
with bounds as (
    select min(order_date) as start_date, max(order_date) as end_date
    from {{ ref('fct_sales') }}
)

select
    cast(d as date)                     as date_day,
    year(d)                             as year,
    quarter(d)                          as quarter,
    month(d)                            as month,
    strftime(d, '%Y-%m')                as year_month,
    strftime(d, '%b')                   as month_name,
    dayofweek(d)                        as day_of_week,
    strftime(d, '%a')                   as day_name,
    dayofweek(d) in (0, 6)              as is_weekend
from bounds, range(start_date, end_date + interval 1 day, interval 1 day) as t(d)
