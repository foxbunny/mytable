# MyTable - Restaurant reservation app

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

## Features

### Back Office (Restaurant Portal)

#### Workflow 1: Phone/In-Person Reservations
- **Search Availability** - Enter date/time/party size, see available tables
- **Create Reservation** - Pick a table and book immediately (pre-confirmed)

#### Workflow 2: Online Reservation Approval
- **Pending Requests Queue** - List of customer requests (date, time, party size, contact info)
- **Process Request** - Click on pending request → runs availability search → pick table → confirm or reject
- **Notification Badge** - Alert when new requests arrive

#### Shared Management
- **Today's View** - All reservations (confirmed, pending, seated, completed)
- **Reservation Status Updates** - Mark as seated, completed, no-show, cancelled

#### Configuration
- **Upload Floor Plan Image** - Background image of restaurant layout
- **Table Layout Editor** - Position tables on floor plan, set capacity for each
- **Operating Hours** - Days/times for reservations
- **Service Duration** - Default reservation length

### Customer Portal

#### Online Booking (Workflow 2)
- **Select Date/Time/Party Size** - Basic availability form
- **Submit Request** - Enter name, phone, email
- **Pending Status** - "Waiting for restaurant confirmation..."
- **Confirmation Update** - Real-time notification when staff approves/rejects
- **Email Notification** - Sent if user leaves before confirmation

#### Manage Reservation
- **View Reservation** - Look up by confirmation number
- **Cancel Reservation** - Self-service cancellation

## The stack

The technology stack comprises of:

- PostgreSQL - the database and business logic
- NpgsqlRest - automatic REST API middleware
- dbmate - database migration tool
- Vanilla frontend

## Development Setup

### Lima VM Setup (macOS)

This project runs in a Lima VM (Linux ARM64). To set up:

1. **Install Lima** (if not already installed):
   ```bash
   brew install lima
   ```

2. **Create and start the VM**:
   ```bash
   limactl start --name=mytable template://ubuntu-lts --cpus=2 --memory=4 --disk=10 --mount-writable
   ```

   This creates a VM with:
   - Ubuntu 24.04 LTS (Noble Numbat)
   - 2 CPU cores
   - 4GB RAM
   - 10GB disk
   - Writable access to your home directory

3. **Run the setup script inside the VM**:
   ```bash
   limactl shell mytable
   ./setup-vm.sh
   exit
   ```

   This script will:
   - Install NpgsqlRest and dbmate binaries
   - Install PostgreSQL 18
   - Configure PostgreSQL for passwordless local access
   - Create the database user and initial database

4. **Verify setup**:
   ```bash
   limactl shell mytable psql -U $(whoami) -d mytable -c "SELECT version();"
   ```

### Running Commands in Lima VM

All database and server commands must run inside the Lima VM:

```bash
# Run a single command
limactl shell mytable dbmate status

# Or enter the VM shell interactively
limactl shell mytable
```

## Database Migrations

Database schema changes are managed using [dbmate](https://github.com/amacneil/dbmate), a lightweight migration tool.

### Directory Structure

```
db/
├── migrations/    # Schema migrations (tables, indexes, etc.)
├── functions/     # Idempotent function definitions (DROP + CREATE)
└── schema.sql     # Auto-generated schema dump
```

- **migrations/**: One-time schema changes managed by dbmate
- **functions/**: Stored functions that are re-applied on every deploy (idempotent)

### Running Migrations

Use `db-migrate.sh` to apply both migrations and functions:

```bash
# Local development
limactl shell mytable ./db-migrate.sh "postgres://$(whoami)@localhost:5432/mytable?sslmode=disable"

# Remote database
./db-migrate.sh "postgres://user:password@remote-host:5432/mytable"

# Or via environment variable
DATABASE_URL="postgres://..." ./db-migrate.sh
```

The script will:
1. Run all pending dbmate migrations
2. Apply all `.sql` files from `db/functions/`

### Creating Migrations

```bash
limactl shell mytable dbmate new create_reservations_table
```

### Creating Functions

Add `.sql` files to `db/functions/`. Functions are applied alphabetically on each deploy.

## Testing

Tests are PostgreSQL procedures in the `test` schema. To add tests, create a `db/tests/` directory with `.sql` files.

```bash
limactl shell mytable ./test-db.sh "postgres://$(whoami)@localhost:5432/mytable?sslmode=disable"
```

## Coding Standards

Coding standards for SQL, JavaScript, CSS, and HTML are documented in `.claude/rules/`.

## Design System

Defined in `public/common.css`, demonstrated at `/design-system.html`.
