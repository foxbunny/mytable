#!/usr/bin/env bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

# Use DATABASE_URL from argument or environment
DATABASE_URL="${1:-$DATABASE_URL}"

if [ -z "$DATABASE_URL" ]; then
	echo "Usage: $0 <DATABASE_URL>"
	echo "   or: DATABASE_URL=... $0"
	exit 1
fi

export DATABASE_URL

# Extract database name from URL (last path component)
DB_NAME=$(echo "$DATABASE_URL" | sed -E 's|.*/([^?]+).*|\1|')

# Build admin URL by replacing the database name with 'postgres'
ADMIN_URL=$(echo "$DATABASE_URL" | sed -E 's|/[^/?]+(\?)|/postgres\1|; s|/[^/?]+$|/postgres|')

# Log target (mask password if present)
echo "Target: $(echo "$DATABASE_URL" | sed -E 's|://([^:]+):[^@]+@|://\1:****@|')"

echo "Terminating connections to '$DB_NAME'..."
psql "$ADMIN_URL" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" > /dev/null

echo "Dropping database '$DB_NAME'..."
psql "$ADMIN_URL" -c "DROP DATABASE IF EXISTS $DB_NAME;"

echo "Creating database '$DB_NAME'..."
psql "$ADMIN_URL" -c "CREATE DATABASE $DB_NAME;"

echo "Running migrations..."
./db-migrate.sh "$DATABASE_URL"
