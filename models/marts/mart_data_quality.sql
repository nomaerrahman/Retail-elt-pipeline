-- How many raw rows each cleaning rule removed. Feeds the README and a dashboard card.
with raw_rows as (
    select count(*) as n from {{ source('raw', 'transactions') }}
),

after_dedup as (
    select quality_status, count(*) as n
    from {{ ref('int_transactions_flagged') }}
    group by 1
)

select 'raw_rows' as step, n as rows from raw_rows
union all
select 'exact_duplicates_removed', (select n from raw_rows) - (select sum(n) from after_dedup)
union all
select quality_status, n from after_dedup
