#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

DATABASE_URL="${1:-$DATABASE_URL}"

if [ -z "$DATABASE_URL" ]; then
    echo "Usage: $0 <DATABASE_URL>"
    echo "   or: DATABASE_URL=... $0"
    exit 1
fi

# Load test procedures
for f in db/tests/*.sql; do
    psql "$DATABASE_URL" -f "$f" -q
done

# Get list of test procedures and run each
tests=$(psql "$DATABASE_URL" -t -A -c "
    SELECT proname FROM pg_proc
    WHERE pronamespace = 'test'::regnamespace
    AND prokind = 'p'
    AND pronargs = 0
    ORDER BY proname
")

passed=0
failed=0

for test in $tests; do
    if psql "$DATABASE_URL" -c "call test.$test()" > /dev/null 2>&1; then
        echo "PASS: $test"
        passed=$((passed + 1))
    else
        echo "FAIL: $test"
        psql "$DATABASE_URL" -c "call test.$test()" 2>&1 | tail -1
        failed=$((failed + 1))
    fi
done

echo ""
echo "$passed passed, $failed failed"

[ $failed -eq 0 ]
