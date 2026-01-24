#!/usr/bin/env bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

NpgsqlRest default.json -o local.json
