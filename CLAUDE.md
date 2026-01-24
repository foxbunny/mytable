# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MyTable is a restaurant reservation application with a database-centric architecture. The project consists of two frontends (customer-facing and restaurant-facing portals) and one backend, deployed as a single-tenant application per restaurant.

This is a **soft-real-time MPA (Multi-Page Application)** - designed for responsive interactions with acceptable latency bounds, using traditional page navigation rather than SPA patterns.

## Problem-Solving Approach

When fixing bugs or implementing features, always consider multiple possible solutions. If more than one viable approach exists, pause and ask the user for their preference before proceeding.

## CRITICAL: Indentation

**ALL files in this project use TABS for indentation. Never use spaces for indentation.** This applies to every file type: JavaScript, CSS, SQL, HTML, JSON, and any other files. When editing or creating files, always use tab characters (`\t`), never spaces.

## Development Environment

**IMPORTANT**: This project runs in a Lima VM (Linux ARM64), not directly on the macOS host.

- **Host OS**: macOS
- **VM**: Lima (Linux ARM64)
- **Database commands** (dbmate, psql, NpgsqlRest): Must be run inside the Lima VM
- **File editing**: Can be done on the macOS host (files are shared with the VM)

To run commands in the Lima VM, use:
```bash
# Run a single command remotely
limactl shell mytable [command]

# Or enter the VM shell interactively
limactl shell mytable
```

The VM name is `mytable`.

**IMPORTANT**: When executing commands via Bash tool, always use `limactl shell mytable [command]` format.

## Technology Stack

- **PostgreSQL 18**: Database and business logic layer (using stored functions/procedures)
- **NpgsqlRest**: Automatic REST API middleware that generates endpoints from database schema
- **dbmate**: Database migration management
- **Vanilla JavaScript**: Frontend (no framework)
- **Design System**: Implemented in `public/common.css`

The architecture is database-centric: all server-side business logic resides in PostgreSQL stored procedures and functions, not in application code. NpgsqlRest automatically exposes these as REST endpoints.

**Endpoint naming:** SQL function names use `snake_case`, but NpgsqlRest converts them to `kebab-case` for URL paths. For example, `customer_create_reservation` becomes `/api/customer-create-reservation`.

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

### Directory Structure

```
db/
├── migrations/    # Schema migrations (tables, indexes, etc.)
├── functions/     # Idempotent function definitions (CREATE OR REPLACE)
└── schema.sql     # Auto-generated schema dump
```

### Running Migrations

Use `db-migrate.sh` to apply migrations and functions:

```bash
# Local development
limactl shell mytable ./db-migrate.sh "postgres://$(whoami)@localhost:5432/mytable?sslmode=disable"

# Remote database
./db-migrate.sh "postgres://user:password@remote-host:5432/mytable"
```

The script runs dbmate migrations first, then applies all `db/functions/*.sql` files.

### Migration Commands

```bash
# Create a new migration (for tables, indexes, constraints)
dbmate new migration_name

# Rollback the last migration
dbmate rollback

# Show migration status
dbmate status
```

### When to Use migrations/ vs functions/

- **migrations/**: Tables, indexes, constraints, data migrations - things that run once
- **functions/**: Stored functions/procedures using `CREATE OR REPLACE` - re-applied on every deploy

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

**Important:** NpgsqlRest will automatically pick up any new functions.

## Development Workflow

1. **Database Changes**: Create migrations using `dbmate new`, write both `migrate:up` and `migrate:down` sections
2. **Apply Migrations**: Run `dbmate up` to apply changes
3. **API Auto-Generation**: NpgsqlRest automatically creates REST endpoints from new database functions/procedures
4. **Frontend Development**: Build vanilla JavaScript frontends that consume the auto-generated API

### Code Review

Run `/project:review` periodically during a session after making changes to ensure code remains consistent with the coding standards in `.claude/rules/`.

## Architecture Principles

- **Database-First**: Business logic lives in PostgreSQL stored procedures/functions
- **API Auto-Generation**: NpgsqlRest generates REST endpoints from database schema - no manual API code
- **Single-Tenant**: Each restaurant deploys their own isolated instance
- **No ORM**: Direct database programming via SQL migrations and stored procedures
- **Multi-Page Application (MPA)**: Traditional page-based navigation with server-rendered HTML, not a single-page app
- **Soft-Real-Time**: Designed for responsive user interactions with acceptable latency bounds, suitable for reservation management workflows

## Frontend Conventions

### Element Selection

- **JavaScript**: Select elements using `data-part` attribute to avoid selector conflicts
- **CSS**: NEVER use `data-part` selectors. Use `id`, `class`, or other attributes instead.

### CSS Selectors

- **Unique elements**: Use `id` as the base selector
- **Repeatable elements**: Use `class` as the selector
- **Scoping**: Use an id or class as a scope, then select elements within (e.g., `#sidebar .link`, `.calendar li:not([hidden])`)

### Document Structure

- HTML structure always lives in `.html` files
- When JavaScript needs to create new elements dynamically, use `<template>` elements defined in HTML

### State Management in the DOM

- **No class manipulation for state**: JavaScript does not add/remove classes to represent state
- **Use data attributes**: Represent state with `data-` attributes (e.g., `data-active`, `data-selected`, `data-loading`, `data-direction="up"`)
- **CSS matches state**: CSS applies styles by matching data attributes (e.g., `[data-active]`, `[data-direction="up"]`)
- **Computed values**: When JavaScript needs to provide computed values to CSS, use custom CSS properties

### CSS Parametrized Declarations

Use CSS custom properties to create reusable, overridable component styles:

```css
/* Define parameters with defaults */
:root {
  --button-bg: gray;
  --button-color: white;
}

/* Parametrized rule uses the variables */
.button {
  background: var(--button-bg);
  color: var(--button-color);
}

/* Override parameters in specific contexts */
.cta {
  --button-bg: blue;
  --button-color: white;
}
```

This pattern creates variants without duplicating declarations. The `.button` rule stays the same; contexts override the parameters.
