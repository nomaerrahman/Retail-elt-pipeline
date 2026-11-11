"""Extract + load step of the ELT pipeline.

Downloads the UCI Online Retail dataset (UK online gift retailer,
Dec 2010 - Dec 2011) and loads it untouched into DuckDB as raw.transactions.
All cleaning happens downstream in dbt, so the raw layer stays an exact copy
of the source.
"""
from pathlib import Path
import urllib.request

import duckdb

SOURCE_URL = (
    "https://raw.githubusercontent.com/databricks/Spark-The-Definitive-Guide/"
    "master/data/retail-data/all/online-retail-dataset.csv"
)
ROOT = Path(__file__).resolve().parents[1]
RAW_CSV = ROOT / "data" / "raw" / "online_retail.csv"
DB_PATH = ROOT / "data" / "retail.duckdb"


def download() -> None:
    RAW_CSV.parent.mkdir(parents=True, exist_ok=True)
    if RAW_CSV.exists():
        print(f"Using cached file {RAW_CSV}")
        return
    print(f"Downloading {SOURCE_URL}")
    urllib.request.urlretrieve(SOURCE_URL, RAW_CSV)


def load() -> None:
    con = duckdb.connect(str(DB_PATH))
    con.execute("create schema if not exists raw")
    # Every column read as text: types are assigned in the dbt staging model.
    con.execute(
        f"""
        create or replace table raw.transactions as
        select *, current_timestamp as _loaded_at
        from read_csv('{RAW_CSV.as_posix()}', header = true, all_varchar = true)
        """
    )
    rows = con.execute("select count(*) from raw.transactions").fetchone()[0]
    print(f"Loaded {rows:,} rows into raw.transactions ({DB_PATH.name})")
    con.close()


if __name__ == "__main__":
    download()
    load()
