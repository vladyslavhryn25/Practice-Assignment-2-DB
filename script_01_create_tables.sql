-- Drop tables in reverse order to avoid foreign key conflicts
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS freelancers;
DROP TABLE IF EXISTS clients;

-- Clients who post projects on the platform
CREATE TABLE clients (
    client_id   UUID PRIMARY KEY,        -- unique identifier generated in Python
    client_name VARCHAR(100) NOT NULL,   -- company or person name
    country     VARCHAR(50)  NOT NULL,   -- country of the client
    email       VARCHAR(100) NOT NULL    -- contact email
);

-- Freelancers who complete projects
CREATE TABLE freelancers (
    freelancer_id   UUID PRIMARY KEY,        -- unique identifier generated in Python
    freelancer_name VARCHAR(100)   NOT NULL, -- full name
    email           VARCHAR(100)   NOT NULL, -- contact email
    hourly_rate     DECIMAL(10, 2) NOT NULL  -- rate per hour in USD
);

-- Service categories (Web Development, Design, SEO, etc.)
CREATE TABLE categories (
    category_id   SERIAL PRIMARY KEY,  -- auto-incremented integer
    category_name VARCHAR(50) NOT NULL
);

-- Projects connecting clients, freelancers and categories
CREATE TABLE projects (
    project_id    SERIAL PRIMARY KEY,
    client_id     UUID           REFERENCES clients(client_id),      -- who ordered the project
    freelancer_id UUID           REFERENCES freelancers(freelancer_id), -- who does the project
    category_id   INTEGER        REFERENCES categories(category_id), -- what type of work
    title         VARCHAR(100)   NOT NULL,
    status        VARCHAR(20)    NOT NULL CHECK (status IN ('Completed', 'In Progress')), -- only two valid values
    budget        DECIMAL(10, 2) NOT NULL, -- agreed project budget in USD
    start_date    DATE           NOT NULL
);

-- Payments made for projects (one project can have multiple payments)
CREATE TABLE payments (
    payment_id   SERIAL PRIMARY KEY,
    project_id   INTEGER        REFERENCES projects(project_id), -- which project this payment belongs to
    amount       DECIMAL(10, 2) NOT NULL,  -- payment amount in USD
    payment_date DATE           NOT NULL   -- when the payment was made
);
