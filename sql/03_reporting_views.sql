use council_spending;

-- VIEW 1 : spend vs budget variance register 

CREATE VIEW variance_register AS
    SELECT 
        council_name,
        department,
        spend_category,
        SUM(CASE
            WHEN recorded_spend = 1 THEN actual_spend_gbp
            ELSE 0
        END) AS recorded_spend,
        SUM(CASE
            WHEN recorded_spend = 1 THEN budget_amount_gbp
            ELSE 0
        END) AS total_budget,
        (SUM(CASE
            WHEN recorded_spend = 1 THEN actual_spend_gbp
            ELSE 0
        END) - SUM(CASE
            WHEN recorded_spend = 1 THEN budget_amount_gbp
            ELSE 0
        END)) AS variance,
        (SUM(CASE
            WHEN recorded_spend = 1 THEN actual_spend_gbp else 0
        END) - SUM(CASE
            WHEN recorded_spend = 1 THEN budget_amount_gbp
        END)) * 100 / NULLIF(SUM(CASE
                    WHEN recorded_spend = 1 THEN budget_amount_gbp else 0
                END),
                0) AS variance_pct,
        SUM(CASE
            WHEN recorded_spend = 1 THEN 1
            ELSE 0
        END) AS transaction_count
    FROM
        accepted_data
    GROUP BY council_name , department , spend_category;
    
    select * from variance_register;
    select count(*) from variance_register;
    
--  VIEW monthly_council_spend AS
CREATE VIEW monthly_council_spend AS
SELECT
    CAST(DATE_FORMAT(transaction_date, '%Y-%m-01') AS DATE)
        AS month_start,
    council_name,

    SUM(CASE
        WHEN recorded_spend = 1 THEN actual_spend_gbp
        ELSE 0
    END) AS recorded_spend_gbp,

    SUM(CASE
        WHEN paid_spend = 1 THEN actual_spend_gbp
        ELSE 0
    END) AS paid_spend_gbp,

    SUM(CASE
        WHEN pending_spend = 1 THEN actual_spend_gbp
        ELSE 0
    END) AS pending_spend_gbp

FROM accepted_data
GROUP BY
    CAST(DATE_FORMAT(transaction_date, '%Y-%m-01') AS DATE),
    council_name;
    
-- see the result chronoligically 
SELECT *
FROM monthly_council_spend
ORDER BY month_start, council_name;

SELECT COUNT(*) AS row_count
FROM monthly_council_spend;

-- View 3 - View 3: The Supplier & Procurement Concentration View
CREATE VIEW procurement_concentration AS
WITH recorded_data AS (
    SELECT
        council_name,
        supplier_name,
        procurement_method,
        funding_source,
        actual_spend_gbp
    FROM accepted_data
    WHERE recorded_spend = 1
),

council_totals AS (
    SELECT
        council_name,
        SUM(actual_spend_gbp) AS council_recorded_spend,

        SUM(CASE
            WHEN supplier_name = 'Not recorded'
                THEN actual_spend_gbp
            ELSE 0
        END) AS not_recorded_spend,

        SUM(CASE
            WHEN procurement_method = 'Direct Award'
                THEN actual_spend_gbp
            ELSE 0
        END) AS direct_award_spend

    FROM recorded_data
    GROUP BY council_name
),

breakdowns AS (
    SELECT
        council_name,
        'Supplier' AS breakdown_type,
        supplier_name AS breakdown_name,
        SUM(actual_spend_gbp) AS recorded_spend_gbp
    FROM recorded_data
    GROUP BY council_name, supplier_name

    UNION ALL

    SELECT
        council_name,
        'Procurement method',
        procurement_method,
        SUM(actual_spend_gbp)
    FROM recorded_data
    GROUP BY council_name, procurement_method

    UNION ALL

    SELECT
        council_name,
        'Funding source',
        funding_source,
        SUM(actual_spend_gbp)
    FROM recorded_data
    GROUP BY council_name, funding_source
)

SELECT
    b.council_name,
    b.breakdown_type,
    b.breakdown_name,
    b.recorded_spend_gbp,
    c.council_recorded_spend,

    b.recorded_spend_gbp * 100.0
        / NULLIF(c.council_recorded_spend, 0)
        AS share_of_council_pct,

    c.not_recorded_spend * 100.0
        / NULLIF(c.council_recorded_spend, 0)
        AS not_recorded_supplier_share_pct,

    c.direct_award_spend * 100.0
        / NULLIF(c.council_recorded_spend, 0)
        AS direct_award_share_pct

FROM breakdowns b
JOIN council_totals c
    ON b.council_name = c.council_name;
    
    SELECT *
FROM procurement_concentration
ORDER BY council_name, breakdown_type, share_of_council_pct DESC;

SELECT COUNT(*) AS row_count
FROM procurement_concentration;

-- View 4: The Payment Status & Data Completeness View
CREATE VIEW governance_payment_summary AS
WITH council_summary AS (
    SELECT
        council_name,
        COUNT(*) AS total_transaction_count,
        SUM(actual_spend_gbp) AS total_value_gbp,

        SUM(CASE WHEN payment_status = 'Paid'
            THEN 1 ELSE 0 END) AS paid_count,
        SUM(CASE WHEN payment_status = 'Paid'
            THEN actual_spend_gbp ELSE 0 END) AS paid_value,

        SUM(CASE WHEN payment_status = 'Approved'
            THEN 1 ELSE 0 END) AS approved_count,
        SUM(CASE WHEN payment_status = 'Approved'
            THEN actual_spend_gbp ELSE 0 END) AS approved_value,

        SUM(CASE WHEN payment_status = 'Pending'
            THEN 1 ELSE 0 END) AS pending_count,
        SUM(CASE WHEN payment_status = 'Pending'
            THEN actual_spend_gbp ELSE 0 END) AS pending_value,

        SUM(CASE WHEN payment_status = 'Under Review'
            THEN 1 ELSE 0 END) AS under_review_count,
        SUM(CASE WHEN payment_status = 'Under Review'
            THEN actual_spend_gbp ELSE 0 END) AS under_review_value,

        SUM(CASE WHEN payment_status = 'Cancelled'
            THEN 1 ELSE 0 END) AS cancelled_count,
        SUM(CASE WHEN payment_status = 'Cancelled'
            THEN actual_spend_gbp ELSE 0 END) AS cancelled_value,

        SUM(CASE WHEN supplier_flag = 1
            THEN 1 ELSE 0 END) AS missing_supplier_count

    FROM accepted_data
    GROUP BY council_name
)

SELECT
    council_name,
    total_transaction_count,
    total_value_gbp,

    paid_count,
    paid_value,
    paid_value * 100.0 / NULLIF(total_value_gbp, 0)
        AS paid_share_pct,

    approved_count,
    approved_value,
    approved_value * 100.0 / NULLIF(total_value_gbp, 0)
        AS approved_share_pct,

    pending_count,
    pending_value,
    pending_value * 100.0 / NULLIF(total_value_gbp, 0)
        AS pending_share_pct,

    under_review_count,
    under_review_value,
    under_review_value * 100.0 / NULLIF(total_value_gbp, 0)
        AS under_review_share_pct,

    cancelled_count,
    cancelled_value,
    cancelled_value * 100.0 / NULLIF(total_value_gbp, 0)
        AS cancelled_share_pct,

    missing_supplier_count,
    missing_supplier_count * 100.0
        / NULLIF(total_transaction_count, 0)
        AS missing_supplier_pct

FROM council_summary;

SELECT *
FROM governance_payment_summary
ORDER BY council_name;

SELECT COUNT(*) AS council_count
FROM governance_payment_summary;

SHOW COLUMNS FROM council_spending.load_audit;

