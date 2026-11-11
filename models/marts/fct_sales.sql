-- Fact table: one row per valid sales line (grain = invoice line).
select
    line_id,
    invoice_no,
    stock_code,
    customer_id,
    cast(invoiced_at as date)            as order_date,
    invoiced_at,
    country,
    quantity,
    unit_price,
    cast(quantity * unit_price as decimal(12, 2)) as line_revenue
from {{ ref('int_transactions_flagged') }}
where quality_status = 'valid_sale'
