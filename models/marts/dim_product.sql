-- One row per product. The same stock code sometimes has several descriptions,
-- so we keep the one used most often.
with descriptions as (
    select
        stock_code,
        description,
        count(*) as uses,
        row_number() over (partition by stock_code order by count(*) desc, description) as rn
    from {{ ref('int_transactions_flagged') }}
    where quality_status = 'valid_sale' and description is not null
    group by 1, 2
),

sales as (
    select
        stock_code,
        sum(quantity)      as units_sold,
        sum(line_revenue)  as revenue,
        median(unit_price) as median_unit_price
    from {{ ref('fct_sales') }}
    group by 1
)

select
    s.stock_code,
    coalesce(d.description, 'UNKNOWN') as description,
    s.units_sold,
    s.revenue,
    s.median_unit_price
from sales s
left join descriptions d on d.stock_code = s.stock_code and d.rn = 1
