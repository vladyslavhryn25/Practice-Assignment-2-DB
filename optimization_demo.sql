
EXPLAIN ANALYZE
SELECT
    sub.freelancer_name,
    sub.total_paid,
    sub.project_count
FROM (
    SELECT
        f.freelancer_name,
        SUM(p.amount)          AS total_paid,
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




CREATE INDEX IF NOT EXISTS idx_payments_payment_date
    ON payments(payment_date);

CREATE INDEX IF NOT EXISTS idx_payments_project_id
    ON payments(project_id);

CREATE INDEX IF NOT EXISTS idx_projects_status
    ON projects(status);

CREATE INDEX IF NOT EXISTS idx_projects_freelancer_id
    ON projects(freelancer_id);




EXPLAIN ANALYZE
WITH filtered_data AS (
    -- Step 1: join and filter once
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
    -- Step 2: aggregate once
    SELECT
        freelancer_name,
        SUM(amount)              AS total_paid,
        COUNT(DISTINCT project_id) AS project_count
    FROM filtered_data
    GROUP BY freelancer_id, freelancer_name
),
ranked AS (
    -- Step 3: rank by total_paid
    SELECT
        freelancer_name,
        total_paid,
        project_count,
        RANK() OVER (ORDER BY total_paid DESC) AS rnk
    FROM agg_data
)
SELECT
    freelancer_name,
    total_paid,
    project_count,
    rnk
FROM ranked
WHERE rnk <= 10
ORDER BY rnk;
