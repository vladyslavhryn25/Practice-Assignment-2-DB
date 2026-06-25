
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS freelancers;
DROP TABLE IF EXISTS clients;

CREATE TABLE clients (
    client_id   UUID PRIMARY KEY,
    client_name VARCHAR(100) NOT NULL,
    country     VARCHAR(50)  NOT NULL,
    email       VARCHAR(100) NOT NULL
);

CREATE TABLE freelancers (
    freelancer_id   UUID PRIMARY KEY,
    freelancer_name VARCHAR(100)   NOT NULL,
    email           VARCHAR(100)   NOT NULL,
    hourly_rate     DECIMAL(10, 2) NOT NULL
);

CREATE TABLE categories (
    category_id   SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL
);

CREATE TABLE projects (
    project_id    SERIAL PRIMARY KEY,
    client_id     UUID           REFERENCES clients(client_id),
    freelancer_id UUID           REFERENCES freelancers(freelancer_id),
    category_id   INTEGER        REFERENCES categories(category_id),
    title         VARCHAR(100)   NOT NULL,
    status        VARCHAR(20)    NOT NULL CHECK (status IN ('Completed', 'In Progress')),
    budget        DECIMAL(10, 2) NOT NULL,
    start_date    DATE           NOT NULL
);

CREATE TABLE payments (
    payment_id   SERIAL PRIMARY KEY,
    project_id   INTEGER        REFERENCES projects(project_id),
    amount       DECIMAL(10, 2) NOT NULL,
    payment_date DATE           NOT NULL
);
