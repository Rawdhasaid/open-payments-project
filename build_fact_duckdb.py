import os
import duckdb

con = duckdb.connect("open_payments.duckdb")

con.execute("INSTALL postgres;")
con.execute("LOAD postgres;")

con.execute(f"""
ATTACH 'host=localhost port=5432 dbname=open_payments_dwh
        user={os.environ["PG_USER"]} password={os.environ["PG_PASSWORD"]}'
AS pg (TYPE postgres, READ_ONLY);
""")

print("Postgres source:", con.execute(
    "SELECT COUNT(*) FROM pg.stg.general_payments_2025_clean"
).fetchone())

# ---------- payments_src (75 columns) ----------
bases = [
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_",
    "Product_Category_or_Therapeutic_Area_",
    "Associated_Drug_or_Biological_NDC_",
    "Associated_Device_or_Medical_Supply_PDI_",
    "Covered_or_Noncovered_Indicator_",
]
product_cols = [f"{b}{i}" for b in bases for i in range(1, 6)]

other_cols = [
    "Record_ID", "Date_of_Payment", "Payment_Publication_Date", "Program_Year",
    "Related_Product_Indicator", "Number_of_Payments_Included_in_Total_Amount",
    "Total_Amount_of_Payment_USDollars",
    "Covered_Recipient_Profile_ID", "Covered_Recipient_NPI",
    "Covered_Recipient_Name_Suffix", "Covered_Recipient_First_Name",
    "Covered_Recipient_Middle_Name", "Covered_Recipient_Last_Name",
    "Recipient_City", "Recipient_Country", "Recipient_Postal_Code",
    "Recipient_Province", "Recipient_State", "Recipient_Zip_Code",
    "Recipient_Primary_Business_Street_Address_Line1",
    "Recipient_Primary_Business_Street_Address_Line2",
    "Covered_Recipient_License_State_code1", "Covered_Recipient_License_State_code2",
    "Covered_Recipient_License_State_code3", "Covered_Recipient_License_State_code4",
    "Covered_Recipient_License_State_code5",
    "Covered_Recipient_Specialty_1", "Covered_Recipient_Specialty_2",
    "Covered_Recipient_Type",
    "Covered_Recipient_Primary_Type_1", "Covered_Recipient_Primary_Type_2",
    "Covered_Recipient_Primary_Type_3", "Covered_Recipient_Primary_Type_4",
    "Covered_Recipient_Primary_Type_5", "Covered_Recipient_Primary_Type_6",
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_ID",
    "Submitting_Applicable_Manufacturer_or_Applicable_GPO_Name",
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Pymnt_Cntry",
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name",
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_State",
    "Form_of_Payment_or_Transfer_of_Value",
    "Nature_of_Payment_or_Transfer_of_Value",
    "Teaching_Hospital_ID", "Teaching_Hospital_CCN", "Teaching_Hospital_Name",
]

select_list = ",\n".join(f'"{c}"' for c in other_cols + product_cols)

con.execute(f"""
CREATE OR REPLACE TABLE payments_src AS
SELECT {select_list}
FROM pg.stg.general_payments_2025_clean
""")

print("payments_src rows:", con.execute("SELECT COUNT(*) FROM payments_src").fetchone())
print("payments_src columns:", len(con.execute("DESCRIBE payments_src").fetchall()))

# ---------- dimensions ----------
dims = [
    "dim_physician",
    "dim_teaching_hospital",
    "dim_manufacturer",
    "dim_product",
    "dim_date",
    "dim_payment_form",
    "dim_payment_nature",
]
for t in dims:
    con.execute(f"CREATE OR REPLACE TABLE {t} AS SELECT * FROM pg.stg.{t}")
    print(t, con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0])

con.close()
print("Done.")