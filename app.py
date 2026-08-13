"""Superstore SQL Analysis — interactive query browser.

Reads queries/analysis.sql, splits it on the '-- Qn.' headers, and lets the
user run each one against superstore.db. The SQL is shown alongside every
result: the queries are the point of this project, not the charts.
"""

import re
import sqlite3

import pandas as pd
import streamlit as st

DB_PATH = "superstore.db"
SQL_PATH = "queries/analysis.sql"

st.set_page_config(page_title="Superstore SQL Analysis", layout="wide")


@st.cache_resource
def get_connection():
    # check_same_thread=False: Streamlit reruns the script on a different
    # thread than the one that opened the connection.
    return sqlite3.connect(DB_PATH, check_same_thread=False)


@st.cache_data
def load_queries():
    """Split analysis.sql into {title: sql} using the '-- Qn.' comment headers."""
    text = open(SQL_PATH).read()
    blocks = re.split(r"^-- Q(\d+)\.\s*", text, flags=re.MULTILINE)[1:]

    queries = {}
    for num, body in zip(blocks[::2], blocks[1::2]):
        lines = body.splitlines()
        # Title = comment lines before the first line of actual SQL.
        title_lines = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("--") and "---" not in stripped:
                title_lines.append(stripped.lstrip("- ").strip())
            elif stripped and not stripped.startswith("--"):
                break
        title = title_lines[0] if title_lines else f"Query {num}"
        sql = "\n".join(l for l in lines if not l.strip().startswith("--")).strip()
        sql = sql.rstrip(";")
        if sql:
            queries[f"Q{num}. {title}"] = sql
    return queries


@st.cache_data
def run(sql):
    return pd.read_sql_query(sql, get_connection())


st.title("Superstore Sales Analysis")
st.caption(
    "~10,000 retail order line-items across three related tables. "
    "Each question below is answered by a single SQL query."
)

try:
    queries = load_queries()
except FileNotFoundError:
    st.error(f"Couldn't find {SQL_PATH}. Run this from the project root.")
    st.stop()

if not queries:
    st.error("No queries parsed — check the '-- Qn.' headers in analysis.sql.")
    st.stop()

choice = st.sidebar.radio("Question", list(queries), label_visibility="collapsed")
sql = queries[choice]

st.subheader(choice)

try:
    df = run(sql)
except Exception as exc:
    st.error(f"Query failed: {exc}")
    st.code(sql, language="sql")
    st.stop()

left, right = st.columns([3, 2])

with left:
    st.dataframe(df, use_container_width=True, hide_index=True)

    # Chart when there's an obvious label + numeric pair.
    numeric = df.select_dtypes("number").columns.tolist()
    labels = [c for c in df.columns if c not in numeric]
    if labels and numeric and len(df) <= 40:
        st.bar_chart(df.set_index(labels[0])[numeric[0]])

with right:
    st.code(sql, language="sql")

st.download_button(
    "Download results as CSV",
    df.to_csv(index=False).encode(),
    file_name=f"{choice.split('.')[0].lower()}_results.csv",
    mime="text/csv",
)
