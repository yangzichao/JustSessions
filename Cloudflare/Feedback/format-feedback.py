"""Show stored feedback, newest first, without Wrangler's execution metadata."""

import json
import sys
import textwrap


def show_feedback(query_results):
    if len(query_results) != 1 or not query_results[0].get("success"):
        raise ValueError("Feedback query did not return one successful result")
    entries = query_results[0]["results"]
    if not entries:
        print("No feedback yet.")
        return
    for entry in entries:
        details = [entry["received_at"], entry["source"]]
        if entry["app_version"]:
            details.append(f"JustSessions {entry['app_version']} · macOS {entry['macos_version']}")
        if entry["contact"]:
            details.append(f"reply to {entry['contact']}")
        print(f"\n#{entry['id']}  " + "  ".join(details))
        for line in entry["message"].splitlines() or [""]:
            print(textwrap.indent(line, "  ") if line else "")


if __name__ == "__main__":
    show_feedback(json.load(sys.stdin))
