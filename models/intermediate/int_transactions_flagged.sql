-- Remove exact duplicate rows and flag every data quality issue in one place,
-- so marts can filter on clear, documented rules.
with deduped as (
    select distinct * from {{ ref('stg_transactions') }}
),

flagged as (
    select
        *,
        -- Postage, fees, manual adjustments and gift vouchers are not products
        (
            stock_code in ('POST', 'DOT', 'M', 'C2', 'D', 'S', 'B', 'BANK CHARGES', 'AMAZONFEE', 'CRUK', 'PADS')
            or stock_code like 'GIFT_%'
        )                                       as is_non_product,
        customer_id is null                     as is_missing_customer,
        unit_price <= 0                         as is_zero_price,
        quantity <= 0 and not is_cancellation   as is_bad_quantity
    from deduped
)

select
    md5(concat_ws('|', invoice_no, stock_code, cast(invoiced_at as varchar), cast(quantity as varchar),
                  cast(unit_price as varchar), coalesce(cast(customer_id as varchar), '')))
        || '-' || cast(row_number() over (
            partition by invoice_no, stock_code, invoiced_at, quantity, unit_price, customer_id
            order by description) as varchar)   as line_id,
    *,
    case
        when is_cancellation      then 'cancellation'
        when is_non_product       then 'non_product'
        when is_missing_customer  then 'missing_customer'
        when is_zero_price        then 'zero_price'
        when is_bad_quantity      then 'bad_quantity'
        else 'valid_sale'
    end                                         as quality_status
from flagged
