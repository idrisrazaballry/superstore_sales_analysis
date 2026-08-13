"""Build superstore.db from the CSVs in data/."""
import sqlite3, pandas as pd, pathlib

DB = "superstore.db"
db = pathlib.Path(DB)
if db.exists():
    db.unlink()

conn = sqlite3.connect(DB)
conn.executescript(open("schema/01_schema.sql").read())

orders = pd.read_csv("data/orders.csv", encoding="latin-1")
orders.columns = (orders.columns.str.strip().str.lower()
                  .str.replace(r"[ -]", "_", regex=True))
# Superstore ships US-format dates; adjust if yours differ.
for col in ("order_date", "ship_date"):
    orders[col] = pd.to_datetime(orders[col], format="mixed").dt.strftime("%Y-%m-%d")
orders.to_sql("orders", conn, if_exists="append", index=False)

for name in ("returns", "managers"):
    df = pd.read_csv(f"data/{name}.csv", encoding="latin-1")
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    df.to_sql(name, conn, if_exists="append", index=False)

for t in ("orders", "returns", "managers"):
    print(t, conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0], "rows")

conn.commit()
conn.close()
