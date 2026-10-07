COPY stg.fct_payments (
    record_id, physician_key, teaching_hospital_key, manufacturer_key, product_key,
    payment_date, payment_date_key, payment_publication_date, publication_date_key,
    payment_year, related_product_indicator, number_of_payments_included_in_total_amount,
    total_payment_us_dollars, payment_form_key, payment_nature_key
)
FROM '/tmp/fct_payments.csv' WITH (FORMAT csv, HEADER true);

   TRUNCATE stg.fct_payments RESTART IDENTITY;
   
   
   SELECT
  COUNT(*)                                               AS total_rows,
  COUNT(*) FILTER (WHERE physician_key IS NULL)          AS no_physician,         -- 35,569
  COUNT(*) FILTER (WHERE teaching_hospital_key IS NULL)  AS no_hospital,          -- 16,096,287
  COUNT(*) FILTER (WHERE manufacturer_key IS NULL)       AS no_manufacturer,      -- 0
  COUNT(*) FILTER (WHERE product_key IS NULL)            AS no_product,           -- 0
  COUNT(*) FILTER (WHERE payment_date_key IS NULL)       AS no_date_key,          -- 0
  COUNT(*) FILTER (WHERE publication_date_key IS NULL)   AS no_pub_date_key,      -- 0
  COUNT(*) FILTER (WHERE payment_form_key IS NULL)       AS no_form,              -- 0
  COUNT(*) FILTER (WHERE payment_nature_key IS NULL)     AS no_nature             -- 0
FROM stg.fct_payments;

ALTER TABLE stg.fct_payments ADD FOREIGN KEY (physician_key)          REFERENCES stg.dim_physician(physician_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (teaching_hospital_key)  REFERENCES stg.dim_teaching_hospital(teaching_hospital_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (manufacturer_key)       REFERENCES stg.dim_manufacturer(manufacturer_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (product_key)            REFERENCES stg.dim_product(product_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (payment_date_key)       REFERENCES stg.dim_date(date_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (publication_date_key)   REFERENCES stg.dim_date(date_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (payment_form_key)       REFERENCES stg.dim_payment_form(payment_form_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (payment_nature_key)     REFERENCES stg.dim_payment_nature(payment_nature_key);


CREATE INDEX ON stg.fct_payments (record_id);
CREATE INDEX ON stg.fct_payments (physician_key);
CREATE INDEX ON stg.fct_payments (teaching_hospital_key);
CREATE INDEX ON stg.fct_payments (manufacturer_key);
CREATE INDEX ON stg.fct_payments (product_key);
CREATE INDEX ON stg.fct_payments (payment_date_key);
ANALYZE stg.fct_payments;


SELECT m.manufacturer_name, SUM(f.total_payment_us_dollars) AS total_usd
FROM stg.fct_payments f
JOIN stg.dim_manufacturer m ON m.manufacturer_key = f.manufacturer_key
GROUP BY 1 ORDER BY 2 DESC LIMIT 5;

SELECT m.manufacturer_name,
       ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_usd
FROM stg.fct_payments f
JOIN stg.dim_manufacturer m ON m.manufacturer_key = f.manufacturer_key
GROUP BY 1 ORDER BY 2 DESC LIMIT 5;


SELECT COUNT(*) FROM stg.fct_payments;   -- 16,131,856

select * from stg.fct_payments 
where teaching_hospital_key is not null limit 10 ;



-- checking the business requirements 

--Which manufacturers are making the highest payments to physicians?

SELECT m.manufacturer_name,
       ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_usd      
FROM stg.fct_payments f
JOIN stg.dim_manufacturer m ON m.manufacturer_key = f.manufacturer_key
join stg.dim_physician p on f.physician_key = p.physician_key
 where physician_type not like '%Covered Recipient Non-Physician Practitioner%'
 GROUP BY 1 order by 2 Desc;

select distinct physician_type from stg.dim_physician

select *  from stg.dim_physician where physician_type like 
'%Covered Recipient Non-Physician Practitioner%'

 SELECT 
    m.manufacturer_name,
    p.physician_key,
    ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_usd      
FROM stg.fct_payments f
JOIN stg.dim_manufacturer m 
    ON m.manufacturer_key = f.manufacturer_key
JOIN stg.dim_physician p 
    ON f.physician_key = p.physician_key
WHERE p.physician_type NOT LIKE '%Covered Recipient Non-Physician Practitioner%'
GROUP BY 
    m.manufacturer_name,
    p.physician_key
ORDER BY total_usd DESC;

---Which physicians received the highest total payments?
SELECT
    p.physician_key,
    p.physician_first_name,
    p.physician_last_name,
    ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_payment_usd
FROM stg.fct_payments f
JOIN stg.dim_physician p
    ON f.physician_key = p.physician_key
WHERE p.physician_type NOT LIKE '%Covered Recipient Non-Physician Practitioner%'
GROUP BY
    p.physician_key,
    p.physician_first_name,
    p.physician_last_name
ORDER BY total_payment_usd DESC;

--What type of payment is most common?
SELECT
    n.nature_of_payment,
    COUNT(*) AS payment_count,
    ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_payment_usd
FROM stg.fct_payments f
JOIN stg.dim_payment_nature n
    ON f.payment_nature_key = n.payment_nature_key
GROUP BY n.nature_of_payment
ORDER BY payment_count DESC;

--the form seems to be more accurate as an answer to the business requirement question 
SELECT
    f.form_of_payment,
    COUNT(*) AS payment_count,
    ROUND(SUM(p.total_payment_us_dollars)::numeric, 2) AS total_payment_usd
FROM stg.fct_payments p
JOIN stg.dim_payment_form f
    ON f.payment_form_key = p.payment_form_key
GROUP BY f.payment_form_key
ORDER BY payment_count DESC;

--Which states or cities have the highest payment activity?

SELECT
    p.physician_state,
    p.physician_city,
    COUNT(*) AS payment_count,
    ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_payment_usd
FROM stg.fct_payments f
JOIN stg.dim_physician p
    ON f.physician_key = p.physician_key
GROUP BY
    p.physician_state,
    p.physician_city
ORDER BY total_payment_usd DESC;


--What is the trend of payments over time?

SELECT
    d.year_number,
    d.month_number,
    d.month_name,
    ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_payment_usd
FROM stg.fct_payments f
JOIN stg.dim_date d
    ON f.payment_date_key = d.date_key
GROUP BY
    d.year_number,
     d.month_name,
    d.month_number
ORDER BY
    d.year_number,
     d.month_name,
    d.month_number;
    
 --Which medical specialties receive the highest payments?
 
    SELECT
    p.physician_specialty_1,
    ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_payment_usd
FROM stg.fct_payments f
JOIN stg.dim_physician p
    ON f.physician_key = p.physician_key
WHERE p.physician_specialty_1 IS NOT NULL
GROUP BY p.physician_specialty_1
ORDER BY total_payment_usd DESC;
 -- added the speciality 2 , seed more accurate to include it. 
SELECT
    s.specialty,
    ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_payment_usd
FROM stg.fct_payments f
JOIN stg.dim_physician p
    ON f.physician_key = p.physician_key
CROSS JOIN LATERAL (
    VALUES (p.physician_specialty_1), (p.physician_specialty_2)
) AS s(specialty)
WHERE s.specialty IS NOT NULL
GROUP BY s.specialty
ORDER BY total_payment_usd DESC;

--Which drugs or medical products are linked with the highest payments?

SELECT
    p.product_name,
    p.product_type,
    ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_payment_usd
FROM stg.fct_payments f
JOIN stg.dim_product p
    ON f.product_key = p.product_key
GROUP BY
    p.product_name,
    p.product_type
ORDER BY total_payment_usd DESC;

--Which payment categories are increasing or decreasing over time?
SELECT
   d.year_number,
    d.month_number,
    n.nature_of_payment,
    ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_payment_usd
FROM stg.fct_payments f
JOIN stg.dim_date d
    ON f.payment_date_key = d.date_key
JOIN stg.dim_payment_nature n
    ON f.payment_nature_key = n.payment_nature_key
GROUP BY
    d.year_number,
    d.month_number,
    n.nature_of_payment
ORDER BY
   d.year_number,
    d.month_number,
    n.nature_of_payment;

    
    
    WITH monthly_payments AS (
    SELECT
        d.year_number,
        d.month_number,
        n.nature_of_payment,
        SUM(f.total_payment_us_dollars) AS total_payment
    FROM stg.fct_payments f
    JOIN stg.dim_date d
        ON f.payment_date_key = d.date_key
    JOIN stg.dim_payment_nature n
        ON f.payment_nature_key = n.payment_nature_key
    GROUP BY
        d.year_number,
        d.month_number,
        n.nature_of_payment
)

SELECT
    *,
    CASE WHEN total_payment > LAG(total_payment) OVER (PARTITION BY nature_of_payment ORDER BY year_number, month_number)
        THEN 'Increasing'
        WHEN total_payment < LAG(total_payment) OVER (PARTITION BY nature_of_payment ORDER BY year_number, month_number )
        THEN 'Decreasing'
        ELSE 'No Change'
    END AS trend
FROM monthly_payments
ORDER BY
    nature_of_payment,
    year_number,
    month_number;
  
  
  --Which payment categories are increasing or decreasing over time? start and end of the year difference   
 SELECT
    d.year_number,
    n.nature_of_payment,
    ROUND(SUM(CASE WHEN d.month_number = 1 THEN f.total_payment_us_dollars ELSE 0 END)::numeric, 2) AS january_payment,
    ROUND(SUM(CASE WHEN d.month_number = 12 THEN f.total_payment_us_dollars ELSE 0 END)::numeric, 2) AS december_payment,
    CASE WHEN SUM(CASE WHEN d.month_number = 12 THEN f.total_payment_us_dollars ELSE 0 END) > SUM(CASE WHEN d.month_number = 1 THEN f.total_payment_us_dollars ELSE 0 END) THEN 'Increasing'
    WHEN SUM(CASE WHEN d.month_number = 12 THEN f.total_payment_us_dollars ELSE 0 END) < SUM (CASE WHEN d.month_number = 1 THEN f.total_payment_us_dollars ELSE 0 END)  THEN 'Decreasing'
    ELSE 'No Change'
    END AS trend
FROM stg.fct_payments f
JOIN stg.dim_date d
    ON f.payment_date_key = d.date_key
JOIN stg.dim_payment_nature n
    ON f.payment_nature_key = n.payment_nature_key
GROUP BY
    d.year_number,
    n.nature_of_payment
ORDER BY
    n.nature_of_payment;   
    
 --Which payment categories are increasing or decreasing over time? Full Year Scan using regr_slope function to get the average change per month and accordingly give the indicator.     
    WITH monthly AS (
    SELECT
        d.year_number,
        n.nature_of_payment,
        d.month_number,
        SUM(f.total_payment_us_dollars) AS month_payment
    FROM stg.fct_payments f
    JOIN stg.dim_date d
        ON f.payment_date_key = d.date_key
    JOIN stg.dim_payment_nature n
        ON f.payment_nature_key = n.payment_nature_key
    GROUP BY d.year_number, n.nature_of_payment, d.month_number
)
SELECT
    year_number,
    nature_of_payment,
    COUNT(*) AS months_with_data,
    ROUND(SUM(month_payment)::numeric, 2) AS year_total,
    ROUND(regr_slope(month_payment, month_number)::numeric, 2) AS slope_per_month,
    CASE
        WHEN COUNT(*) < 2 THEN 'Not enough data'
        WHEN regr_slope(month_payment, month_number) > 0 THEN 'Increasing'
        WHEN regr_slope(month_payment, month_number) < 0 THEN 'Decreasing'
        ELSE 'No Change'
    END AS trend
FROM monthly
GROUP BY year_number, nature_of_payment
ORDER BY nature_of_payment, year_number;
    
    