#!/usr/bin/env bash
# Prints JustSessions update checks per UTC day, newest first, with each day's split by app version.
set -euo pipefail

number_of_days="${1:-30}"
if ! [[ "$number_of_days" =~ ^[0-9]+$ ]]; then
    echo "usage: $0 [number of days, default 30]" >&2
    exit 64
fi

cd "$(dirname "$0")"
wrangler d1 execute justsessions-update-checks --remote --command "
    SELECT
        utc_day,
        SUM(check_count) AS update_checks,
        GROUP_CONCAT(app_version || ': ' || check_count, ', ') AS by_app_version
    FROM (SELECT * FROM daily_update_checks ORDER BY app_version DESC)
    GROUP BY utc_day
    ORDER BY utc_day DESC
    LIMIT $number_of_days"
