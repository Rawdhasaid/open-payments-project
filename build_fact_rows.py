import duckdb

con = duckdb.connect("open_payments.duckdb")
con.execute("SET temp_directory = 'duck_tmp'")
con.execute("SET max_temp_directory_size = '20GB'")

def h(exprs):
    parts = ",".join(f"coalesce({e}::VARCHAR,'<NULL>')" for e in exprs)
    return f"md5(concat_ws('|',{parts}))"

def dim_cols(table, skip):
    return [r[0] for r in con.execute(f"DESCRIBE {table}").fetchall()][skip:]

# ---- physician ----
phys_src = ["Covered_Recipient_NPI","Covered_Recipient_Name_Suffix","Covered_Recipient_First_Name",
 "Covered_Recipient_Middle_Name","Covered_Recipient_Last_Name","Recipient_City","Recipient_Country",
 "Recipient_Postal_Code","Recipient_Province","Recipient_State","Recipient_Zip_Code",
 "Recipient_Primary_Business_Street_Address_Line1","Recipient_Primary_Business_Street_Address_Line2",
 "Covered_Recipient_License_State_code1","Covered_Recipient_License_State_code2",
 "Covered_Recipient_License_State_code3","Covered_Recipient_License_State_code4",
 "Covered_Recipient_License_State_code5","Covered_Recipient_Specialty_1","Covered_Recipient_Specialty_2",
 "Covered_Recipient_Type","Covered_Recipient_Primary_Type_1","Covered_Recipient_Primary_Type_2",
 "Covered_Recipient_Primary_Type_3","Covered_Recipient_Primary_Type_4","Covered_Recipient_Primary_Type_5",
 "Covered_Recipient_Primary_Type_6"]
phys_dim = dim_cols("dim_physician", 2)
assert len(phys_src) == len(phys_dim)
phys_h_src = h([f'p."{c}"' for c in phys_src])
phys_h_dim = h([f"ph.{c}" for c in phys_dim])

# ---- teaching hospital (UPPER on text, same as the dimension) ----
hosp_src = ["Teaching_Hospital_CCN","Teaching_Hospital_Name",
 "Recipient_Primary_Business_Street_Address_Line1","Recipient_Primary_Business_Street_Address_Line2",
 "Recipient_City","Recipient_State","Recipient_Zip_Code","Recipient_Country"]
hosp_dim = dim_cols("dim_teaching_hospital", 2)
assert len(hosp_src) == len(hosp_dim)
hosp_h_src = h([f'p."{c}"' if c == "Teaching_Hospital_CCN" else f'UPPER(p."{c}")' for c in hosp_src])
hosp_h_dim = h([f"th.{c}" for c in hosp_dim])

# ---- manufacturer (UPPER only on the two name columns) ----
man_src = ["Applicable_Manufacturer_or_Applicable_GPO_Making_Pymnt_Cntry",
 "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name",
 "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_State",
 "Submitting_Applicable_Manufacturer_or_Applicable_GPO_Name"]
man_dim = ["manufacturer_country","manufacturer_name","manufacturer_state","submitting_manufacturer_gpo_name"]
upper_src = {"Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name",
             "Submitting_Applicable_Manufacturer_or_Applicable_GPO_Name"}
man_h_src = h([f'UPPER(p."{c}")' if c in upper_src else f'p."{c}"' for c in man_src])
man_h_dim = h([f"m.{c}" for c in man_dim])

# ---- product (30 columns, 34K-row dimension) ----
bases = ["Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_",
         "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_",
         "Product_Category_or_Therapeutic_Area_","Associated_Drug_or_Biological_NDC_",
         "Associated_Device_or_Medical_Supply_PDI_","Covered_or_Noncovered_Indicator_"]
prod_src = [f"{b}{i}" for b in bases for i in range(1, 6)]
prod_dim = dim_cols("dim_product", 1)
assert len(prod_src) == len(prod_dim)
prod_h_src = h([f'p."{c}"' for c in prod_src])
prod_h_dim = h([f"pr.{c}" for c in prod_dim])

con.execute(f"""
CREATE OR REPLACE TABLE fct_build AS
SELECT
  p."Record_ID"                                   AS record_id,
  ph.physician_key,
  th.teaching_hospital_key,
  m.manufacturer_key,
  pr.product_key,
  CAST(p."Date_of_Payment" AS DATE)               AS payment_date,
  d1.date_key                                     AS payment_date_key,
  CAST(p."Payment_Publication_Date" AS DATE)      AS payment_publication_date,
  d2.date_key                                     AS publication_date_key,
  p."Program_Year"                                AS payment_year,
  p."Related_Product_Indicator"                   AS related_product_indicator,
  p."Number_of_Payments_Included_in_Total_Amount" AS number_of_payments_included_in_total_amount,
  p."Total_Amount_of_Payment_USDollars"           AS total_payment_us_dollars,
  pf.payment_form_key,
  pn.payment_nature_key
FROM payments_src p
LEFT JOIN dim_physician ph
  ON p."Covered_Recipient_Profile_ID" = ph.physician_profile_id
 AND {phys_h_src} = {phys_h_dim}
LEFT JOIN dim_teaching_hospital th
  ON p."Teaching_Hospital_ID" = th.teaching_hospital_id
 AND {hosp_h_src} = {hosp_h_dim}
LEFT JOIN dim_manufacturer m
  ON p."Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_ID" = m.manufacturer_id
 AND {man_h_src} = {man_h_dim}
LEFT JOIN dim_product pr
  ON {prod_h_src} = {prod_h_dim}
LEFT JOIN dim_date d1 ON CAST(p."Date_of_Payment" AS DATE) = d1.date
LEFT JOIN dim_date d2 ON CAST(p."Payment_Publication_Date" AS DATE) = d2.date
LEFT JOIN dim_payment_form pf   ON p."Form_of_Payment_or_Transfer_of_Value" = pf.form_of_payment
LEFT JOIN dim_payment_nature pn ON p."Nature_of_Payment_or_Transfer_of_Value" = pn.nature_of_payment
""")

print(con.execute("""
SELECT
  COUNT(*)                                                                                AS total_rows,
  COUNT(*) FILTER (WHERE physician_key IS NULL)                                           AS no_physician,
  COUNT(*) FILTER (WHERE teaching_hospital_key IS NULL)                                   AS no_hospital,
  COUNT(*) FILTER (WHERE physician_key IS NULL AND teaching_hospital_key IS NULL)         AS neither,
  COUNT(*) FILTER (WHERE physician_key IS NOT NULL AND teaching_hospital_key IS NOT NULL) AS both_keys,
  COUNT(*) FILTER (WHERE manufacturer_key IS NULL)                                        AS no_manufacturer,
  COUNT(*) FILTER (WHERE product_key IS NULL)                                             AS no_product,
  COUNT(*) FILTER (WHERE payment_date_key IS NULL)                                        AS no_date_key,
  COUNT(*) FILTER (WHERE publication_date_key IS NULL)                                    AS no_pub_date_key,
  COUNT(*) FILTER (WHERE payment_form_key IS NULL)                                        AS no_form,
  COUNT(*) FILTER (WHERE payment_nature_key IS NULL)                                      AS no_nature
FROM fct_build
""").fetchall())
con.close()