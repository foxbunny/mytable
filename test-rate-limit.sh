#!/usr/bin/env bash

# Test rate limiter using Apache Bench
# Usage: ./test-rate-limit.sh [url] [requests]

URL="${1:-http://localhost:8080/api/is-setup}"
REQUESTS="${2:-80}"

echo "Rate Limit Test"
echo "==============="
echo "URL: $URL"
echo "Requests: $REQUESTS"
echo ""

result=$(ab -n "$REQUESTS" -c 1 "$URL" 2>&1)

# Extract stats
complete=$(echo "$result" | grep "^Complete requests:" | awk '{print $3}')
non2xx=$(echo "$result" | grep "^Non-2xx responses:" | awk '{print $3}')
rps=$(echo "$result" | grep "^Requests per second:" | awk '{print $4}')

success=$((complete - ${non2xx:-0}))

echo "Successful (2xx):   $success"
echo "Rate limited (429): ${non2xx:-0}"
echo "Requests/second:    $rps"
echo ""

if [ -n "$non2xx" ] && [ "$non2xx" -gt 0 ]; then
	echo "Rate limiting is working!"
else
	echo "No rate-limited responses detected."
fi
