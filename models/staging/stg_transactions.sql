-- Rename to snake_case and cast types. No rows are removed here.
with source as (
    select * from {{ source('raw', 'transactions') }}
)

select
    trim(InvoiceNo)                                         as invoice_no,
    upper(trim(StockCode))                                  as stock_code,
    nullif(trim(Description), '')                           as description,
    cast(Quantity as integer)                               as quantity,
    strptime(InvoiceDate, '%m/%d/%Y %H:%M')                 as invoiced_at,
    cast(UnitPrice as decimal(10, 2))                       as unit_price,
    cast(cast(nullif(trim(CustomerID), '') as double) as integer) as customer_id,
    trim(Country)                                           as country,
    starts_with(trim(InvoiceNo), 'C')                       as is_cancellation
from source
