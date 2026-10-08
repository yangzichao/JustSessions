"""Show aggregate D1 query results without Wrangler's execution metadata."""

import json
import sys


def show_traffic_tables(query_results):
    table_titles = ("Daily page views (UTC)", "Sources", "Countries", "Devices")
    if len(query_results) != len(table_titles) or not all(result.get("success") for result in query_results):
        raise ValueError("Website traffic query did not return four successful results")
    for title, result in zip(table_titles, query_results):
        print(f"\n{title}")
        rows = result["results"]
        if not rows:
            print("  No page views recorded yet.")
            continue
        columns = list(rows[0])
        widths = [max(len(column), *(len(str(row[column])) for row in rows)) for column in columns]
        print("  " + "  ".join(column.ljust(width) for column, width in zip(columns, widths)))
        for row in rows:
            print("  " + "  ".join(str(row[column]).ljust(width) for column, width in zip(columns, widths)))


if __name__ == "__main__":
    show_traffic_tables(json.load(sys.stdin))
