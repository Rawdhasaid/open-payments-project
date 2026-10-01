import duckdb
con = duckdb.connect("open_payments.duckdb", read_only=True)
con.execute("""
COPY (SELECT * FROM fct_build ORDER BY record_id)
TO 'fct_payments.csv' (HEADER, DELIMITER ',')
""")
print("done")