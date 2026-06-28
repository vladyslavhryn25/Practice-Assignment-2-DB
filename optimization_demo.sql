-- STEP 1: Non-optimized query
-- The same JOIN across 3 tables (payments - projects - freelancers)
-- runs 3 separate times: once for the main result, once to find MAX,
-- PostgreSQL has to scan and re-join the full dataset every time,
-- which makes this query slow on large data.

EXPLAIN ANALYZE
SELECT
    sub.freelancer_name,
    sub.total_paid,
    sub.project_count
FROM (
    -- Main aggregation: total payments and project count per freelancer
    SELECT
        f.freelancer_name,
        SUM(p.amount)                 AS total_paid,
        COUNT(DISTINCT pr.project_id) AS project_count
    FROM payments p
    JOIN projects pr
        ON p.project_id = pr.project_id
    JOIN freelancers f
        ON pr.freelancer_id = f.freelancer_id
    WHERE pr.status = 'Completed'
      AND p.payment_date >= CURRENT_DATE - INTERVAL '1 year'
    GROUP BY f.freelancer_name
) AS sub
WHERE sub.total_paid = (
    -- Correlated subquery #1: find the maximum total_paid value
    -- runs the full JOIN again just to get one number
    SELECT MAX(inner_sub.total_paid)
    FROM (
        SELECT
            SUM(p2.amount) AS total_paid
        FROM payments p2
        JOIN projects pr2
            ON p2.project_id = pr2.project_id
        JOIN freelancers f2
            ON pr2.freelancer_id = f2.freelancer_id
        WHERE pr2.status = 'Completed'
          AND p2.payment_date >= CURRENT_DATE - INTERVAL '1 year'
        GROUP BY f2.freelancer_name
    ) AS inner_sub
)
OR sub.total_paid >= (
    -- Correlated subquery #2: find the 95th percentile of total_paid
    -- runs the full JOIN a third time
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY inner_sub2.total_paid)
    FROM (
        SELECT
            SUM(p3.amount) AS total_paid
        FROM payments p3
        JOIN projects pr3
            ON p3.project_id = pr3.project_id
        JOIN freelancers f3
            ON pr3.freelancer_id = f3.freelancer_id
        WHERE pr3.status = 'Completed'
          AND p3.payment_date >= CURRENT_DATE - INTERVAL '1 year'
        GROUP BY f3.freelancer_name
    ) AS inner_sub2
)
ORDER BY sub.total_paid DESC
LIMIT 10;



-- STEP 2: Add indexes
-- Indexes allow PostgreSQL to find matching rows without scanning
-- the entire table (Index Scan instead of Sequential Scan).


-- Index on payment_date speeds up the WHERE date filter
CREATE INDEX IF NOT EXISTS idx_payments_payment_date
    ON payments(payment_date);

-- Index on project_id speeds up the JOIN between payments and projects
CREATE INDEX IF NOT EXISTS idx_payments_project_id
    ON payments(project_id);

-- Index on status speeds up the WHERE status = 'Completed' filter
CREATE INDEX IF NOT EXISTS idx_projects_status
    ON projects(status);

-- Index on freelancer_id speeds up the JOIN between projects and freelancers
CREATE INDEX IF NOT EXISTS idx_projects_freelancer_id
    ON projects(freelancer_id);


-- STEP 3: Optimized query with CTEs
-- Instead of running the same JOIN 3 times, we do it once
-- inside the first CTE (filtered_data) and reuse the result.
-- RANK() window function replaces the correlated subqueries
-- for finding top earners - no extra table scans needed.

EXPLAIN ANALYZE
WITH filtered_data AS (
    -- Step 1: join and filter once - result is reused in the next CTE
    SELECT
        f.freelancer_id,
        f.freelancer_name,
        pr.project_id,
        p.amount
    FROM payments p
    JOIN projects pr
        ON p.project_id = pr.project_id
    JOIN freelancers f
        ON pr.freelancer_id = f.freelancer_id
    WHERE pr.status = 'Completed'
      AND p.payment_date >= CURRENT_DATE - INTERVAL '1 year'
),
agg_data AS (
    -- Step 2: aggregate once using the already filtered data
    SELECT
        freelancer_name,
        SUM(amount)                AS total_paid,
        COUNT(DISTINCT project_id) AS project_count
    FROM filtered_data
    GROUP BY freelancer_id, freelancer_name
),
ranked AS (
    -- Step 3: assign rank by total_paid — no extra subquery needed
    SELECT
        freelancer_name,
        total_paid,
        project_count,
        RANK() OVER (ORDER BY total_paid DESC) AS rnk
    FROM agg_data
)
-- Final result: take only top 10
SELECT
    freelancer_name,
    total_paid,
    project_count,
    rnk
FROM ranked
WHERE rnk <= 10
ORDER BY rnk;
