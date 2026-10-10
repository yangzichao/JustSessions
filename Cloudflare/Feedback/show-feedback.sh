#!/usr/bin/env bash
set -euo pipefail

number_of_entries="${1:-20}"
if ! [[ "$number_of_entries" =~ ^[0-9]{1,4}$ ]] || (( 10#$number_of_entries < 1 )); then
    echo "usage: $0 [number of newest entries, 1-9999, default 20]" >&2
    exit 64
fi

cd "$(dirname "$0")"
wrangler d1 execute justsessions-feedback --remote --command "
    SELECT id, received_at, source, contact, app_version, macos_version, message
    FROM feedback ORDER BY id DESC LIMIT $((10#$number_of_entries));" --json | python3 format-feedback.py
