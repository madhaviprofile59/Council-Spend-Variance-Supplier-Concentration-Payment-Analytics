use council_spending;

SHOW VARIABLES LIKE 'secure_file_priv';

SHOW COLUMNS FROM council_spending.accepted_data;

SELECT COUNT(*) AS existing_rows
FROM council_spending.accepted_data;

SHOW CREATE TABLE council_spending.accepted_data;

-- Loading data through INFILE
LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/accepted_data.csv'
INTO TABLE council_spending.accepted_data_import
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    transaction_id,
    @transaction_date,
    council_name,
    department,
    spend_category,
    @original_supplier_name,
    description_column,
    actual_spend_gbp,
    budget_amount_gbp,
    spend_type,
    @original_payment_status,
    procurement_method,
    funding_source,
    currency,
    supplier_name,
    @supplier_flag,
    payment_status,
    @recorded_spend,
    @paid_spend,
    @pending_spend,
    @variance_gbp,
    @variance_pct,
    @supplier_share
)
SET
    transaction_date =
        STR_TO_DATE(TRIM(@transaction_date), '%d/%m/%Y'),

    supplier_flag = CASE LOWER(TRIM(@supplier_flag))
        WHEN 'true' THEN 1
        WHEN 'false' THEN 0
        ELSE CAST(NULLIF(@supplier_flag, '') AS UNSIGNED)
    END,

    recorded_spend = CASE LOWER(TRIM(@recorded_spend))
        WHEN 'true' THEN 1
        WHEN 'false' THEN 0
        ELSE CAST(NULLIF(@recorded_spend, '') AS UNSIGNED)
    END,

    paid_spend = CASE LOWER(TRIM(@paid_spend))
        WHEN 'true' THEN 1
        WHEN 'false' THEN 0
        ELSE CAST(NULLIF(@paid_spend, '') AS UNSIGNED)
    END,

    pending_spend = CASE LOWER(TRIM(@pending_spend))
        WHEN 'true' THEN 1
        WHEN 'false' THEN 0
        ELSE CAST(NULLIF(@pending_spend, '') AS UNSIGNED)
    END,

    Variance_GBP = NULLIF(@variance_gbp, ''),

    Variance_pct = NULLIF(@variance_pct, ''),

    Supplier_Share_Of_Council_Pct =
        NULLIF(TRIM(TRAILING '\r' FROM @supplier_share), '');
        
show warnings;

SHOW COLUMNS
FROM council_spending.accepted_data_import
LIKE 'Variance_pct';

SELECT COUNT(*) AS imported_rows
FROM council_spending.accepted_data_import;

SELECT
    transaction_id,
    transaction_date,
    supplier_name,
    payment_status,
    supplier_flag,
    Variance_pct
FROM council_spending.accepted_data_import
LIMIT 10;
SET SQL_SAFE_UPDATES = 0;

START TRANSACTION;

-- DELETE FROM council_spending.accepted_data;

INSERT INTO council_spending.accepted_data
SELECT *
FROM council_spending.accepted_data_import;

SELECT COUNT(*) AS final_rows
FROM council_spending.accepted_data;

COMMIT;
SET SQL_SAFE_UPDATES = 1;
