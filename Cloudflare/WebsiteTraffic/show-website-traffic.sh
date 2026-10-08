#!/usr/bin/env bash
set -euo pipefail

number_of_days="${1:-30}"
if ! [[ "$number_of_days" =~ ^[0-9]{1,3}$ ]] || (( 10#$number_of_days < 1 || 10#$number_of_days > 180 )); then
    echo "usage: $0 [number of days, 1-180, default 30]" >&2
    exit 64
fi
previous_days=$((10#$number_of_days - 1))

cd "$(dirname "$0")"
wrangler d1 execute justsessions-website-traffic --remote --command "
    SELECT utc_day, page, SUM(page_views) AS page_views
    FROM daily_website_traffic WHERE utc_day >= date('now', '-$previous_days days')
    GROUP BY utc_day, page ORDER BY utc_day DESC, page;
    SELECT source, SUM(page_views) AS page_views
    FROM daily_website_traffic WHERE utc_day >= date('now', '-$previous_days days')
    GROUP BY source ORDER BY page_views DESC;
    SELECT country, SUM(page_views) AS page_views
    FROM daily_website_traffic WHERE utc_day >= date('now', '-$previous_days days')
    GROUP BY country ORDER BY page_views DESC;
    SELECT device, SUM(page_views) AS page_views
    FROM daily_website_traffic WHERE utc_day >= date('now', '-$previous_days days')
    GROUP BY device ORDER BY page_views DESC;" --json | python3 format-website-traffic.py
