
-- DIM_PAYMENT_FORM

insert into stg.dim_payment_form ( form_of_payment )
select  distinct "Form_of_Payment_or_Transfer_of_Value" 
from stg.general_payments_2025_clean;

 -- DIM_PAYMENT_NATURE
 
 insert into stg.dim_payment_nature (nature_of_payment) 
 select distinct "Nature_of_Payment_or_Transfer_of_Value"
  from stg.general_payments_2025_clean;
  
  
  -- DIM_MANUFACTURER 
  INSERT INTO  stg.dim_manufacturer (
    manufacturer_id,
    manufacturer_country,
    manufacturer_name,
    manufacturer_state,
    submitting_manufacturer_gpo_name
)
SELECT DISTINCT
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_ID",
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Pymnt_Cntry",
    UPPER("Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name"),
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_State",
   UPPER("Submitting_Applicable_Manufacturer_or_Applicable_GPO_Name") 
FROM stg.general_payments_2025_clean
WHERE "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_ID" IS NOT NULL;

-- DIM_DATE 

INSERT INTO stg.dim_date (
    DATE_KEY,
    date,
    day_of_month,
    day_name,
    day_of_week,
    week_of_year,
    month_number,
    month_name,
    quarter_number,
    year_number,
    year_month,
    year_quarter,
    is_weekend,
    is_holiday
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT AS date_key,
    d::DATE,
    EXTRACT(DAY FROM d)::INT,
    TO_CHAR(d, 'FMDay'),
    EXTRACT(ISODOW FROM d)::INT,
    EXTRACT(WEEK FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    TO_CHAR(d, 'FMMonth'),
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(YEAR FROM d)::INT,
    TO_CHAR(d, 'YYYYMM')::INT,
    (
        EXTRACT(YEAR FROM d)::INT * 10
        + EXTRACT(QUARTER FROM d)::INT
    ),
    CASE
        WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN 'Y'
        ELSE 'N'
    END,
    'N'
FROM generate_series(
    (
        SELECT LEAST(
            MIN("Date_of_Payment"),
            MIN("Payment_Publication_Date")
        )
        FROM stg.general_payments_2025_clean
    ),
    (
        SELECT GREATEST(
            MAX("Date_of_Payment"),
            MAX("Payment_Publication_Date")
        )
        FROM stg.general_payments_2025_clean
    ),
    INTERVAL '1 day'
) AS d;

--Physician Dimension 
INSERT INTO stg.dim_physician
 (
 physician_profile_id,
 physician_npi,
 physician_name_suffix,
 physician_first_name,
 physician_middle_name,
 physician_last_name,
 physician_city, 
 physician_country,
 physician_postal_code,
 physician_province,
 physician_state,
 physician_zip_code,
 physician_street_address_line1,
 physician_street_address_line2,
 physician_license_state_cd1,
 physician_license_state_cd2,
 physician_license_state_cd3,
 physician_license_state_cd4,
 physician_license_state_cd5,
 physician_specialty_1,
 physician_specialty_2,
 physician_type,
 physician_primary_type_1,
 physician_primary_type_2,
 physician_primary_type_3,
 physician_primary_type_4,
 physician_primary_type_5,
 physician_primary_type_6) 
 
 SELECT DISTINCT
"Covered_Recipient_Profile_ID",
"Covered_Recipient_NPI",
"Covered_Recipient_Name_Suffix",
"Covered_Recipient_First_Name",
"Covered_Recipient_Middle_Name",
"Covered_Recipient_Last_Name",
"Recipient_City",
"Recipient_Country",
"Recipient_Postal_Code",
"Recipient_Province",
"Recipient_State",
"Recipient_Zip_Code",
"Recipient_Primary_Business_Street_Address_Line1",
"Recipient_Primary_Business_Street_Address_Line2",
"Covered_Recipient_License_State_code1",
"Covered_Recipient_License_State_code2",
"Covered_Recipient_License_State_code3",
"Covered_Recipient_License_State_code4",
"Covered_Recipient_License_State_code5",
"Covered_Recipient_Specialty_1",
"Covered_Recipient_Specialty_2",
"Covered_Recipient_Type",
"Covered_Recipient_Primary_Type_1",
"Covered_Recipient_Primary_Type_2",
"Covered_Recipient_Primary_Type_3",
"Covered_Recipient_Primary_Type_4",
"Covered_Recipient_Primary_Type_5",
"Covered_Recipient_Primary_Type_6"
FROM stg.general_payments_2025_clean
 WHERE "Covered_Recipient_Profile_ID" IS NOT NULL 
 AND "Covered_Recipient_Type" NOT like '%Covered Recipient Teaching Hospital%';
 
--fact insertion query which have taken more than 3 hours and never loaded the data.
--Loading of the fact has been changed to usage of duck DB as an in the middle tool to help load the data faster. 

INSERT INTO STG.fct_payments (
    record_id,
    recipient_key,
    manufacturer_key,
    product_key,
    payment_date,
    payment_date_key,
    payment_publication_date,
    publication_date_key,
    payment_year,
    related_product_indicator,
    number_of_payments_included_in_total_amount,
    total_payment_us_dollars,
    payment_form_key,
    payment_nature_key
)
 
SELECT
  raw_pay."Record_ID",
    rec.recipient_key,
    man.manufacturer_key,
    p.product_key,
    raw_pay."Date_of_Payment",
    pd.date_key,
    raw_pay."Payment_Publication_Date",
    pub.date_key,
    raw_pay."Program_Year",
    raw_pay."Related_Product_Indicator",
    raw_pay."Number_of_Payments_Included_in_Total_Amount",
    raw_pay."Total_Amount_of_Payment_USDollars",
    payf.payment_form_key,
    paynat.payment_nature_key
        FROM stg.general_payments_2025_clean raw_pay
         left JOIN STG.dim_manufacturer man
        ON raw_pay."Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_ID"
        = man.manufacturer_id
        AND raw_pay."Submitting_Applicable_Manufacturer_or_Applicable_GPO_Name"
        = man.submitting_manufacturer_gpo_name
        AND raw_pay."Applicable_Manufacturer_or_Applicable_GPO_Making_Pymnt_Cntry" 
        = man.manufacturer_country
        and raw_pay."Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name"
        = man.manufacturer_name
        And raw_pay."Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_State" = man.manufacturer_state
    
        left JOIN STG.dim_product p
        ON p.name_of_drug_or_biological_or_device_or_medical_supply_1
        IS NOT DISTINCT FROM raw_pay."Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_1"
        AND p.name_of_drug_or_biological_or_device_or_medical_supply_2
        IS NOT DISTINCT FROM raw_pay."Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_2"
        AND p.name_of_drug_or_biological_or_device_or_medical_supply_3
        IS NOT DISTINCT FROM raw_pay."Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_3"
        AND p.name_of_drug_or_biological_or_device_or_medical_supply_4
        IS NOT DISTINCT FROM raw_pay."Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_4"
        AND p.name_of_drug_or_biological_or_device_or_medical_supply_5
        IS NOT DISTINCT FROM raw_pay."Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_5"

        LEFT JOIN STG.dim_recipient rec
        ON raw_pay."Covered_Recipient_Profile_ID"
        = rec.recipient_profile_id
        and raw_pay."Covered_Recipient_NPI" = rec.recipient_npi
        LEFT JOIN STG.dim_date pd
         ON raw_pay."Date_of_Payment" = pd.date
        LEFT JOIN STG.dim_date pub
        ON raw_pay."Payment_Publication_Date" = pub.date

        LEFT JOIN STG.dim_payment_nature paynat
        ON raw_pay."Nature_of_Payment_or_Transfer_of_Value"
        = paynat.nature_of_payment

        LEFT JOIN STG.dim_payment_form payf
        ON raw_pay."Form_of_Payment_or_Transfer_of_Value"
        = payf.form_of_payment
        
        where raw_pay."Date_of_Payment" between date '2025-1-01' and date '2025-04-30';
       -- and  man.manufacturer_key is not null
        --limit 1000;
        

-- Teaching Hospital Dimension 

  insert into stg.Dim_Teaching_Hospital(
        Teaching_Hospital_ID,
        Teaching_Hospital_CCN,
        Teaching_Hospital_Name,
        Teaching_Hospital_street_address_line1 ,
        Teaching_Hospital_street_address_line2,
        Teaching_Hospital_city ,
        Teaching_Hospital_state ,
        Teaching_Hospital_zip_code,
        Teaching_Hospital_country
        )
                SELECT DISTINCT
                        "Teaching_Hospital_ID",
                        "Teaching_Hospital_CCN",
                        "Teaching_Hospital_Name",
                        "Recipient_Primary_Business_Street_Address_Line1",
                        "Recipient_Primary_Business_Street_Address_Line2",
                        "Recipient_City",
                        "Recipient_State",
                        "Recipient_Zip_Code",
                        "Recipient_Country"
                FROM stg.general_payments_2025_clean
                where "Covered_Recipient_Type" like '%Covered Recipient Teaching Hospital%' ;                



-- Product Dimension 
INSERT INTO stg.dim_product (
    name_of_drug_or_biological_or_device_or_medical_supply_1,
    name_of_drug_or_biological_or_device_or_medical_supply_2,
    name_of_drug_or_biological_or_device_or_medical_supply_3,
    name_of_drug_or_biological_or_device_or_medical_supply_4,
    name_of_drug_or_biological_or_device_or_medical_supply_5,
    indicate_drug_or_biological_or_device_or_medical_supply_1,
    indicate_drug_or_biological_or_device_or_medical_supply_2,
    indicate_drug_or_biological_or_device_or_medical_supply_3,
    indicate_drug_or_biological_or_device_or_medical_supply_4,
    indicate_drug_or_biological_or_device_or_medical_supply_5,
    product_category_or_therapeutic_area_1,
    product_category_or_therapeutic_area_2,
    product_category_or_therapeutic_area_3,
    product_category_or_therapeutic_area_4,
    product_category_or_therapeutic_area_5,
    associated_drug_or_biological_ndc_1,
    associated_drug_or_biological_ndc_2,
    associated_drug_or_biological_ndc_3,
    associated_drug_or_biological_ndc_4,
    associated_drug_or_biological_ndc_5,
    associated_device_or_medical_supply_pdi_1,
    associated_device_or_medical_supply_pdi_2,
    associated_device_or_medical_supply_pdi_3,
    associated_device_or_medical_supply_pdi_4,
    associated_device_or_medical_supply_pdi_5,
    covered_or_noncovered_indicator_1,
    covered_or_noncovered_indicator_2,
    covered_or_noncovered_indicator_3,
    covered_or_noncovered_indicator_4,
    covered_or_noncovered_indicator_5
)
SELECT DISTINCT
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_1",
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_2",
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_3",
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_4",
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_5",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_1",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_2",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_3",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_4",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_5",
    "Product_Category_or_Therapeutic_Area_1",
    "Product_Category_or_Therapeutic_Area_2",
    "Product_Category_or_Therapeutic_Area_3",
    "Product_Category_or_Therapeutic_Area_4",
    "Product_Category_or_Therapeutic_Area_5",
    "Associated_Drug_or_Biological_NDC_1",
    "Associated_Drug_or_Biological_NDC_2",
    "Associated_Drug_or_Biological_NDC_3",
    "Associated_Drug_or_Biological_NDC_4",
    "Associated_Drug_or_Biological_NDC_5",
    "Associated_Device_or_Medical_Supply_PDI_1",
    "Associated_Device_or_Medical_Supply_PDI_2",
    "Associated_Device_or_Medical_Supply_PDI_3",
    "Associated_Device_or_Medical_Supply_PDI_4",
    "Associated_Device_or_Medical_Supply_PDI_5",
    "Covered_or_Noncovered_Indicator_1",
    "Covered_or_Noncovered_Indicator_2",
    "Covered_or_Noncovered_Indicator_3",
    "Covered_or_Noncovered_Indicator_4",
    "Covered_or_Noncovered_Indicator_5"
FROM stg.general_payments_2025_clean;