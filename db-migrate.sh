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

# Log target (mask password if present)
echo "Target: $(echo "$DATABASE_URL" | sed -E 's|://([^:]+):[^@]+@|://\1:****@|')"

# Run dbmate migrations
echo "Running dbmate migrations..."
dbmate up

# Apply functions from db/functions/
if [ -d "db/functions" ] && [ "$(ls -A db/functions/*.sql 2>/dev/null)" ]; then
    echo "Applying functions from db/functions/..."
    for f in db/functions/*.sql; do
        echo "  Applying $(basename "$f")"
        psql "$DATABASE_URL" -f "$f"
    done
    echo "Functions applied."
else
    echo "No functions to apply."
fi
