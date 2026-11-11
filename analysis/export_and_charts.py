"""Export the dbt marts for Power BI and draw the README charts.

Run after `dbt build`:  python analysis/export_and_charts.py
"""
from pathlib import Path

import duckdb
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.ticker import FuncFormatter

ROOT = Path(__file__).resolve().parents[1]
EXPORT = ROOT / "powerbi" / "data"
DOCS = ROOT / "docs"
EXPORT.mkdir(parents=True, exist_ok=True)
DOCS.mkdir(exist_ok=True)

SURFACE, INK, INK2, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#898781", "#e6e5e0"
BLUE, ORANGE = "#2a78d6", "#eb6834"
plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 10, "text.color": INK,
    "axes.edgecolor": GRID, "axes.labelcolor": INK2, "xtick.color": MUTED, "ytick.color": MUTED,
    "axes.spines.top": False, "axes.spines.right": False, "figure.facecolor": SURFACE,
    "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE, "axes.axisbelow": True,
})

con = duckdb.connect(str(ROOT / "data" / "retail.duckdb"), read_only=True)

# 1. CSV exports for Power BI (star schema + helper marts)
for table in ["fct_sales", "dim_customer", "dim_product", "dim_date",
              "mart_monthly_kpis", "mart_cohort_retention", "mart_data_quality"]:
    con.execute(f"copy marts.{table} to '{(EXPORT / f'{table}.csv').as_posix()}' (header, delimiter ',')")
print(f"Exported marts to {EXPORT}")

# 2. Monthly revenue trend
kpi = con.execute("select * from marts.mart_monthly_kpis order by year_month").df()
fig, ax = plt.subplots(figsize=(9, 4))
x = range(len(kpi))
full = kpi.iloc[:-1]
ax.plot(list(x)[:-1], full["revenue"] / 1e3, color=BLUE, lw=2, marker="o", ms=5)
ax.plot(list(x)[-2:], kpi["revenue"].iloc[-2:] / 1e3, color=BLUE, lw=2, ls=(0, (3, 3)))
ax.plot(list(x)[-1], kpi["revenue"].iloc[-1] / 1e3, "o", color=BLUE, mfc=SURFACE, ms=6, mew=2)
peak = kpi["revenue"].idxmax()
ax.annotate(f"Nov 2011 peak: £{kpi['revenue'][peak]/1e6:.2f}M", (peak, kpi["revenue"][peak] / 1e3),
            xytext=(-150, 0), textcoords="offset points", va="center", color=INK2)
ax.annotate("Dec 2011: data ends 9 Dec", (len(kpi) - 1, kpi["revenue"].iloc[-1] / 1e3),
            xytext=(-150, -12), textcoords="offset points", color=MUTED, fontsize=9)
ax.set_xticks(list(x), kpi["year_month"], rotation=45, ha="right")
ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"£{v:,.0f}k"))
ax.grid(axis="y", color=GRID, lw=0.8)
ax.set_ylim(0, None)
ax.set_title("Monthly revenue, Dec 2010 – Dec 2011", loc="left", fontsize=12, color=INK)
fig.tight_layout()
fig.savefig(DOCS / "monthly_revenue.png", dpi=160)
plt.close(fig)

# 3. RFM segments: share of customers vs share of revenue
seg = con.execute("""
    select rfm_segment,
           100.0 * count(*) / sum(count(*)) over ()            as pct_customers,
           100.0 * sum(revenue) / sum(sum(revenue)) over ()    as pct_revenue
    from marts.dim_customer group by 1 order by pct_revenue
""").df()
fig, ax = plt.subplots(figsize=(9, 4))
y = range(len(seg))
h = 0.36
ax.barh([i + h / 2 + 0.01 for i in y], seg["pct_customers"], height=h, color=BLUE, label="Share of customers")
ax.barh([i - h / 2 - 0.01 for i in y], seg["pct_revenue"], height=h, color=ORANGE, label="Share of revenue")
for i, (c, r) in enumerate(zip(seg["pct_customers"], seg["pct_revenue"])):
    ax.text(c + 0.8, i + h / 2, f"{c:.0f}%", va="center", color=INK2, fontsize=9)
    ax.text(r + 0.8, i - h / 2, f"{r:.0f}%", va="center", color=INK2, fontsize=9)
ax.set_yticks(list(y), seg["rfm_segment"], color=INK2)
ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:.0f}%"))
ax.grid(axis="x", color=GRID, lw=0.8)
ax.legend(loc="lower right", frameon=False)
ax.set_title("Champions are 22% of customers but 65% of revenue", loc="left", fontsize=12, color=INK)
fig.tight_layout()
fig.savefig(DOCS / "rfm_segments.png", dpi=160)
plt.close(fig)

# 4. Cohort retention heatmap (months 1-12)
ret = con.execute("""
    select cohort_month, months_since_first, retention_rate
    from marts.mart_cohort_retention where months_since_first between 1 and 12
""").df().pivot(index="cohort_month", columns="months_since_first", values="retention_rate")
cmap = LinearSegmentedColormap.from_list("blue", ["#cde2fb", "#6da7ec", "#2a78d6", "#184f95", "#0d366b"])
fig, ax = plt.subplots(figsize=(9, 5))
im = ax.imshow(ret.values * 100, cmap=cmap, aspect="auto", vmin=0, vmax=60)
for (i, j), v in __import__("numpy").ndenumerate(ret.values):
    if v == v:  # skip NaN
        ax.text(j, i, f"{v*100:.0f}", ha="center", va="center", fontsize=8,
                color="#ffffff" if v * 100 > 30 else INK)
ax.set_xticks(range(ret.shape[1]), [str(c) for c in ret.columns])
ax.set_yticks(range(ret.shape[0]), ret.index)
ax.set_xlabel("Months since first order")
for s in ax.spines.values():
    s.set_visible(False)
cb = fig.colorbar(im, ax=ax, fraction=0.03, pad=0.02)
cb.outline.set_visible(False)
cb.set_label("% of cohort ordering again", color=INK2)
ax.set_title("Cohort retention (%): most cohorts settle at 20–30% of customers ordering again", loc="left", fontsize=12, color=INK)
fig.tight_layout()
fig.savefig(DOCS / "cohort_retention.png", dpi=160)
plt.close(fig)
print(f"Charts saved to {DOCS}")
