import uuid
import random
from datetime import datetime, timedelta

import psycopg2
from psycopg2.extras import execute_values
from faker import Faker

# --- Database connection settings ---
HOST     = 'localhost'
USER     = 'postgres'
PASSWORD = '123'
DATABASE = 'postgres'
PORT     = '5432'

# --- How many rows to generate ---
CLIENTS_COUNT     = 10_000
FREELANCERS_COUNT = 10_000
PROJECTS_COUNT    = 50_000
PAYMENTS_COUNT    = 100_000
CHUNK_SIZE        = 5_000   # insert in chunks to avoid memory issues

fake = Faker()

# Available service categories
CATEGORIES = [
    'Web Development',
    'Mobile Development',
    'Graphic Design',
    'Copywriting',
    'SEO',
    'Data Analysis',
    'DevOps',
]

# Possible project statuses
STATUSES = ['Completed', 'In Progress']


def insert_categories(cursor):
    print("Inserting categories...")
    data = [(name,) for name in CATEGORIES]
    # RETURNING category_id lets us get back the generated IDs
    execute_values(cursor, "INSERT INTO categories (category_name) VALUES %s RETURNING category_id", data)
    ids = [row[0] for row in cursor.fetchall()]
    print(f"Inserted {len(ids)} categories.")
    return ids


def insert_clients(cursor):
    print("Inserting clients...")
    query = "INSERT INTO clients (client_id, client_name, country, email) VALUES %s"
    client_ids = []

    for start in range(0, CLIENTS_COUNT, CHUNK_SIZE):
        chunk = min(CHUNK_SIZE, CLIENTS_COUNT - start)
        data = []
        for _ in range(chunk):
            cid = str(uuid.uuid4())   # generate unique UUID for each client
            client_ids.append(cid)
            data.append((
                cid,
                fake.company()[:100],  # truncate to fit VARCHAR(100)
                fake.country()[:50],   # truncate to fit VARCHAR(50)
                fake.email()[:100],
            ))
        execute_values(cursor, query, data)
        print(f"  clients: {start + chunk}/{CLIENTS_COUNT}")

    print("Done inserting clients.")
    return client_ids


def insert_freelancers(cursor):
    print("Inserting freelancers...")
    query = "INSERT INTO freelancers (freelancer_id, freelancer_name, email, hourly_rate) VALUES %s"
    freelancer_ids = []

    for start in range(0, FREELANCERS_COUNT, CHUNK_SIZE):
        chunk = min(CHUNK_SIZE, FREELANCERS_COUNT - start)
        data = []
        for _ in range(chunk):
            fid = str(uuid.uuid4())   # unique UUID for each freelancer
            freelancer_ids.append(fid)
            data.append((
                fid,
                fake.name(),
                fake.email(),
                round(random.uniform(10, 100), 2),  # hourly rate between $10 and $100
            ))
        execute_values(cursor, query, data)
        print(f"  freelancers: {start + chunk}/{FREELANCERS_COUNT}")

    print("Done inserting freelancers.")
    return freelancer_ids


def insert_projects(cursor, client_ids, freelancer_ids, category_ids):
    print("Inserting projects...")
    query = """
        INSERT INTO projects
            (client_id, freelancer_id, category_id, title, status, budget, start_date)
        VALUES %s
        RETURNING project_id
    """
    project_ids = []
    # generate start dates within the last 3 years
    start_range = datetime.now() - timedelta(days=365 * 3)

    for start in range(0, PROJECTS_COUNT, CHUNK_SIZE):
        chunk = min(CHUNK_SIZE, PROJECTS_COUNT - start)
        data = []
        for _ in range(chunk):
            data.append((
                random.choice(client_ids),       # random client
                random.choice(freelancer_ids),   # random freelancer
                random.choice(category_ids),     # random category
                fake.bs()[:100],                 # random business-sounding title
                random.choice(STATUSES),         # Completed or In Progress
                round(random.uniform(200, 5000), 2),  # budget between $200 and $5000
                (start_range + timedelta(days=random.randint(0, 365 * 3))).date(),
            ))
        execute_values(cursor, query, data)
        project_ids.extend([row[0] for row in cursor.fetchall()])
        print(f"  projects: {start + chunk}/{PROJECTS_COUNT}")

    print("Done inserting projects.")
    return project_ids


def insert_payments(cursor, project_ids):
    print("Inserting payments...")
    query = "INSERT INTO payments (project_id, amount, payment_date) VALUES %s"
    start_range = datetime.now() - timedelta(days=365 * 3)

    for start in range(0, PAYMENTS_COUNT, CHUNK_SIZE):
        chunk = min(CHUNK_SIZE, PAYMENTS_COUNT - start)
        data = []
        for _ in range(chunk):
            data.append((
                random.choice(project_ids),           # random existing project
                round(random.uniform(50, 2500), 2),   # payment amount between $50 and $2500
                (start_range + timedelta(days=random.randint(0, 365 * 3))).date(),
            ))
        execute_values(cursor, query, data)
        print(f"  payments: {start + chunk}/{PAYMENTS_COUNT}")

    print("Done inserting payments.")


def main():
    # connect to PostgreSQL
    conn = psycopg2.connect(
        host=HOST, user=USER, password=PASSWORD, dbname=DATABASE, port=PORT
    )
    try:
        with conn:
            with conn.cursor() as cur:
                # insert in the correct order to satisfy foreign key constraints
                category_ids   = insert_categories(cur)
                client_ids     = insert_clients(cur)
                freelancer_ids = insert_freelancers(cur)
                project_ids    = insert_projects(cur, client_ids, freelancer_ids, category_ids)
                insert_payments(cur, project_ids)
        print("\nAll data inserted successfully!")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
