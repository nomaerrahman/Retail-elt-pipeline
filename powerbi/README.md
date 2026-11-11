# Power BI dashboard

The dashboard reads the CSV exports of the dbt marts. Generate them first:

```bash
python ingest/ingest.py
dbt build --profiles-dir .
python analysis/export_and_charts.py   # writes powerbi/data/*.csv
```

Then build it in Power BI Desktop (Windows) and save it here as `retail_kpi_dashboard.pbix`.

## 1. Load and model

1. **Get data → Text/CSV**, load all seven files from `powerbi/data/`.
2. In **Model view**, create these relationships (all single direction, many-to-one):

| From (many) | To (one) |
| --- | --- |
| `fct_sales[customer_id]` | `dim_customer[customer_id]` |
| `fct_sales[stock_code]` | `dim_product[stock_code]` |
| `fct_sales[order_date]` | `dim_date[date_day]` |

3. Mark `dim_date` as the date table (**Table tools → Mark as date table**, column `date_day`).

## 2. Measures (DAX)

Create a blank table called `_Measures` and add:

```DAX
Revenue = SUM ( fct_sales[line_revenue] )

Orders = DISTINCTCOUNT ( fct_sales[invoice_no] )

Customers = DISTINCTCOUNT ( fct_sales[customer_id] )

Avg Order Value = DIVIDE ( [Revenue], [Orders] )

Revenue MoM % =
VAR prev = CALCULATE ( [Revenue], DATEADD ( dim_date[date_day], -1, MONTH ) )
RETURN DIVIDE ( [Revenue] - prev, prev )

Top 20% Customer Revenue Share =
VAR ranked =
    TOPN ( ROUND ( COUNTROWS ( dim_customer ) * 0.2, 0 ), dim_customer, dim_customer[revenue], DESC )
RETURN DIVIDE ( SUMX ( ranked, dim_customer[revenue] ), SUM ( dim_customer[revenue] ) )
```

## 3. Pages

| Page | Visuals |
| --- | --- |
| **Overview** | Cards: Revenue, Orders, Customers, Avg Order Value, Top 20% Customer Revenue Share · Line chart: Revenue by `dim_date[year_month]` · Map or bar: Revenue by `fct_sales[country]` · Slicer: `dim_date[year_month]` |
| **Customers (RFM)** | Clustered bar: customers and revenue by `dim_customer[rfm_segment]` · Table: top 20 customers by revenue with segment · Slicer: `dim_customer[country]` |
| **Retention** | Matrix: rows `mart_cohort_retention[cohort_month]`, columns `months_since_first`, values `retention_rate` (format as %, conditional formatting background colour scale) |
| **Data quality** | Table or bar from `mart_data_quality`: rows removed by each cleaning rule |

Export a screenshot of each page to `docs/` and add it to the main README.
