USE council_spending;

-- Run in one Workbench connection. Use the latest quality_summary.csv.
SET @input_count = 50000;
SET @accepted_count = 49570;
SET @rejected_count = 180;
SET @review_count = 250;
SET @expected_actual = 617074279.84;
SET @expected_budget = 648478779.91;

-- STEP 1: Run through SHOW WARNINGS, then inspect Action Output.
-- Start a new run and commit its audit entry independently.
SET @load_conditions = NULL, @rejected_conditions = NULL, @review_conditions = NULL, @ready = 0;

INSERT INTO load_audit (
    source_filename, started_at, input_count, accepted_count,
    rejected_count, review_count, status
)
VALUES (
    'accepted_council_spend.csv', NOW(), @input_count, @accepted_count,
    @rejected_count, @review_count, 'started'
);
SET @run_id = LAST_INSERT_ID();
COMMIT;

TRUNCATE TABLE accepted_data_import;

-- Verify this positional field list against the regenerated CSV header.
LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/accepted_council_spend.csv'
INTO TABLE accepted_data_import
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    transaction_id, @transaction_date, council_name, department,
    spend_category, supplier_name, description_column,
    actual_spend_gbp, budget_amount_gbp, spend_type,
    @original_payment_status, procurement_method, funding_source, currency,
    @supplier_flag, payment_status, @recorded_spend, @paid_spend,
    @pending_spend, @variance_gbp, @variance_pct, @supplier_share
)
SET
    transaction_date = STR_TO_DATE(TRIM(@transaction_date), '%Y-%m-%d'),
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

    Variance_GBP = ROUND(CAST(NULLIF(TRIM(@variance_gbp), '') AS DECIMAL(40,20)), 2),
    Variance_pct = ROUND(CAST(NULLIF(TRIM(@variance_pct), '') AS DECIMAL(40,20)), 6),
    Supplier_Share_Of_Council_Pct =
        NULLIF(TRIM(TRAILING '\r' FROM @supplier_share), '');

-- Capture diagnostics directly after LOAD DATA.
GET DIAGNOSTICS @load_conditions = NUMBER;
SHOW WARNINGS;

-- STEP 2: Run the validation. A result of 1 allows promotion.
SELECT COUNT(*), SUM(actual_spend_gbp), SUM(budget_amount_gbp)
INTO @staged_count, @staged_actual, @staged_budget
FROM accepted_data_import;

UPDATE load_audit
SET staged_count = @staged_count
WHERE run_id = @run_id AND status = 'started';
COMMIT;

SELECT COALESCE(
    @load_conditions = 0
    AND @staged_count = @accepted_count
    AND @staged_count > 0
    AND @input_count = @accepted_count + @rejected_count + @review_count
    AND @staged_actual = @expected_actual
    AND @staged_budget = @expected_budget
    AND @staged_count = (SELECT COUNT(DISTINCT transaction_id) FROM accepted_data_import)
    AND (SELECT COUNT(*) FROM information_schema.tables
         WHERE table_schema = DATABASE()
           AND table_name IN ('accepted_data', 'load_audit', 'rejected_data', 'review_data')
           AND engine = 'InnoDB') = 4
    AND EXISTS (SELECT 1 FROM load_audit WHERE run_id = @run_id AND status = 'started')
    AND NOT EXISTS (
        SELECT 1 FROM accepted_data_import
           WHERE NULLIF(TRIM(transaction_id), '') IS NULL
              OR transaction_date IS NULL
              OR NULLIF(TRIM(council_name), '') IS NULL
              OR NULLIF(TRIM(department), '') IS NULL
              OR currency IS NULL OR currency <> 'GBP'
              OR actual_spend_gbp IS NULL OR actual_spend_gbp < 0
              OR budget_amount_gbp IS NULL
              OR NULLIF(TRIM(supplier_name), '') IS NULL
              OR supplier_flag IS NULL OR supplier_flag NOT IN (0, 1)
              OR (supplier_flag = 1 AND supplier_name <> 'Not recorded')
              OR payment_status IS NULL
              OR payment_status NOT IN ('paid', 'approved', 'pending', 'under review', 'cancelled')
              OR NOT (recorded_spend <=> (payment_status <> 'cancelled'))
              OR NOT (paid_spend <=> (payment_status = 'paid'))
              OR NOT (pending_spend <=> (payment_status IN ('approved', 'pending', 'under review')))
    ), 0) INTO @ready;

UPDATE load_audit
SET ended_at = NOW(),
    status = IF(COALESCE(@load_conditions = 0, 0), 'validation_failed', 'load_failed'),
    error_message = 'CSV import or staging validation failed'
WHERE run_id = @run_id AND status = 'started' AND @ready = 0;
COMMIT;

SELECT @ready AS ready_to_promote, @staged_count AS staged_count,
       @staged_actual AS staged_actual, @staged_budget AS staged_budget;

-- STEP 3: Run only if ready_to_promote = 1. Keep this connection open.
SET @previous_safe_updates = @@SESSION.sql_safe_updates;
SET SESSION sql_safe_updates = 0;
START TRANSACTION;

-- Exception files must have the original 14 columns followed by reason_code.
-- Confirm the headers before running this block.
LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/rejected_council_spend.csv'
INTO TABLE rejected_data
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    @exception_transaction_id, @exception_date, @skip_council, @skip_department, @skip_category,
    @skip_supplier, @skip_description, @exception_actual, @skip_budget, @skip_type,
    @skip_status, @skip_method, @skip_funding, @skip_currency, @exception_reason
)
SET audit_run_id = @run_id,
    transaction_id = NULLIF(@exception_transaction_id, ''),
    transaction_date_raw = NULLIF(@exception_date, ''),
    reason_code = TRIM(TRAILING '\r' FROM @exception_reason);
GET DIAGNOSTICS @rejected_conditions = NUMBER;
SHOW WARNINGS;

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/review_council_spend.csv'
INTO TABLE review_data
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    @exception_transaction_id, @exception_date, @skip_council, @skip_department, @skip_category,
    @skip_supplier, @skip_description, @exception_actual, @skip_budget, @skip_type,
    @skip_status, @skip_method, @skip_funding, @skip_currency, @exception_reason
)
SET audit_run_id = @run_id,
    transaction_id = NULLIF(@exception_transaction_id, ''),
    actual_spend_gbp = NULLIF(TRIM(@exception_actual), ''),
    reason_code = TRIM(TRAILING '\r' FROM @exception_reason);
GET DIAGNOSTICS @review_conditions = NUMBER;
SHOW WARNINGS;

SELECT COUNT(*) INTO @rejected_rows FROM rejected_data WHERE audit_run_id = @run_id;
SELECT COUNT(*) INTO @review_rows FROM review_data WHERE audit_run_id = @run_id;

SET @ready = COALESCE(
    @ready = 1
    AND @rejected_conditions = 0 AND @review_conditions = 0
    AND @rejected_rows = @rejected_count AND @review_rows = @review_count
    AND NOT EXISTS (SELECT 1 FROM rejected_data WHERE audit_run_id = @run_id AND TRIM(reason_code) = '')
    AND NOT EXISTS (SELECT 1 FROM review_data WHERE audit_run_id = @run_id AND TRIM(reason_code) = ''), 0);

SELECT @ready AS exceptions_passed, @rejected_rows AS rejected_rows, @review_rows AS review_rows;

    DELETE FROM accepted_data WHERE @ready = 1;

    INSERT INTO accepted_data (
        transaction_id, transaction_date, council_name, department,
        spend_category, supplier_name, description_column,
        actual_spend_gbp, budget_amount_gbp, spend_type, payment_status,
        procurement_method, funding_source, currency, supplier_flag,
        recorded_spend, paid_spend, pending_spend,
        Variance_GBP, Variance_pct, Supplier_Share_Of_Council_Pct
    )
    SELECT
        transaction_id, transaction_date, council_name, department,
        spend_category, supplier_name, description_column,
        actual_spend_gbp, budget_amount_gbp, spend_type, payment_status,
        procurement_method, funding_source, currency, supplier_flag,
        recorded_spend, paid_spend, pending_spend,
        Variance_GBP, Variance_pct, Supplier_Share_Of_Council_Pct
    FROM accepted_data_import
    WHERE @ready = 1;

SELECT COUNT(*), SUM(actual_spend_gbp), SUM(budget_amount_gbp)
INTO @final_count, @final_actual, @final_budget
FROM accepted_data;

SELECT @final_count AS final_count,
       @final_actual AS final_actual,
       @final_budget AS final_budget,
       COALESCE(@final_count = @staged_count
                AND @final_actual = @staged_actual
                AND @final_budget = @staged_budget, 0) AS final_check_passed;
-- STEP 4: Run only after the insert succeeded without warnings
-- and final_check_passed = 1. Check that the update affected one row.
UPDATE load_audit
SET final_count = @final_count, ended_at = NOW(),
    status = 'succeeded', error_message = NULL
WHERE run_id = @run_id AND status = 'started' AND @ready = 1
  AND @final_count = @staged_count
  AND @final_actual = @staged_actual
  AND @final_budget = @staged_budget;

-- Run separately after confirming the audit update affected one row.
-- COMMIT;
-- SET SESSION sql_safe_updates = @previous_safe_updates;

SELECT * FROM load_audit WHERE run_id = @run_id;