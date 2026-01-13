# MyTable - Restauran reservation app

MyTable comprises of two frontends and one backend. The two frontends are:

- customer-facing portal for making reservation
- restaurant-facing portal for managing reservations

## Architecture

MyTable is:

- web-based
- client-server
- single-tenant
- database-centric
- multi-page application
- soft-real-time

It is a single-tenant application in that each restaurant will deploy exactly one instance for itself.

It is database-centric in that the server-side business logic is entirely contained within the database using stored functions and procedures.

## The stack

The technology stack comprises of:

- PostgreSQL - the database and business logic
- NpgsqlRest - automatic REST API middleware
- dbmate - database migration tool
- Vanilla frontend

## Database Migrations

Database schema changes are managed using [dbmate](https://github.com/amacneil/dbmate), a lightweight migration tool.

### Setup

Set your database connection URL:

```bash
export DATABASE_URL="postgres://$(whoami)@localhost:5432/mytable?sslmode=disable"
```

Or create a `.env` file in the project root:

```
DATABASE_URL=postgres://$(whoami)@localhost:5432/mytable?sslmode=disable
```

### Common Commands

```bash
# Create a new migration
dbmate new create_reservations_table

# Apply all pending migrations
dbmate up

# Rollback the last migration
dbmate rollback

# Show migration status
dbmate status
```

### Migration File Structure

Migrations are SQL files in the `db/migrations/` directory with the format:

```sql
-- migrate:up
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    reservation_time TIMESTAMP NOT NULL
);

-- migrate:down
DROP TABLE reservations;
```
