# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MyTable is a restaurant reservation application with a database-centric architecture. The project consists of two frontends (customer-facing and restaurant-facing portals) and one backend, deployed as a single-tenant application per restaurant.

This is a **soft-real-time MPA (Multi-Page Application)** - designed for responsive interactions with acceptable latency bounds, using traditional page navigation rather than SPA patterns.

## Technology Stack

- **PostgreSQL 18**: Database and business logic layer (using stored functions/procedures)
- **NpgsqlRest**: Automatic REST API middleware that generates endpoints from database schema
- **dbmate**: Database migration management
- **Vanilla JavaScript**: Frontend (no framework)

The architecture is database-centric: all server-side business logic resides in PostgreSQL stored procedures and functions, not in application code. NpgsqlRest automatically exposes these as REST endpoints.

## Configuration

### Database Connection

The project uses configuration files for database connections:

- `default.json` - Default configuration (committed, uses postgres/postgres credentials)
- `local.json` - Local overrides (not committed, create from `local.example.json`)

To set up local configuration:
```bash
cp local.example.json local.json
# Edit local.json with your username (no password needed if following setup-vm.sh configuration)
```

### NpgsqlRest Configuration

Key configuration in `default.json`:
- `UrlPathPrefix: "api"` - All REST endpoints are under `/api`
- `DefaultHttpMethod: "POST"` - Database functions default to POST
- `NameConverter: "CamelCase"` - Converts PostgreSQL snake_case to camelCase in API
- `CommentsMode: "ParseAll"` - Uses PostgreSQL comments for API documentation
- `RequiresAuthorization: false` - Currently no auth (will change for production)

## Database Migrations

### Setup Environment

Set the database connection URL:
```bash
export DATABASE_URL="postgres://$(whoami)@localhost:5432/mytable?sslmode=disable"
```

Or create a `.env` file:
```
DATABASE_URL=postgres://$(whoami)@localhost:5432/mytable?sslmode=disable
```

### Migration Commands

```bash
# Create a new migration
dbmate new migration_name

# Apply all pending migrations
dbmate up

# Rollback the last migration
dbmate rollback

# Show migration status
dbmate status
```

### Migration File Format

Migrations are stored in `db/migrations/` as SQL files:

```sql
-- migrate:up
-- SQL to apply the migration

-- migrate:down
-- SQL to rollback the migration
```

## Running the Application

### Development Setup (Linux ARM64 VM)

The `setup-vm.sh` script automates setup on Linux ARM64 systems:
- Installs NpgsqlRest binary to `/usr/local/bin/`
- Installs dbmate binary to `/usr/local/bin/`
- Installs PostgreSQL 18
- Configures PostgreSQL for passwordless local access
- Creates database user and initial database

```bash
./setup-vm.sh
```

### Starting the API Server

```bash
NpgsqlRest [options]
```

The NpgsqlRest server reads configuration from `default.json` and `local.json`, automatically generating REST endpoints from the PostgreSQL database schema.

## Development Workflow

1. **Database Changes**: Create migrations using `dbmate new`, write both `migrate:up` and `migrate:down` sections
2. **Apply Migrations**: Run `dbmate up` to apply changes
3. **API Auto-Generation**: NpgsqlRest automatically creates REST endpoints from new database functions/procedures
4. **Frontend Development**: Build vanilla JavaScript frontends that consume the auto-generated API

## Architecture Principles

- **Database-First**: Business logic lives in PostgreSQL stored procedures/functions
- **API Auto-Generation**: NpgsqlRest generates REST endpoints from database schema - no manual API code
- **Single-Tenant**: Each restaurant deploys their own isolated instance
- **No ORM**: Direct database programming via SQL migrations and stored procedures
- **Multi-Page Application (MPA)**: Traditional page-based navigation with server-rendered HTML, not a single-page app
- **Soft-Real-Time**: Designed for responsive user interactions with acceptable latency bounds, suitable for reservation management workflows
