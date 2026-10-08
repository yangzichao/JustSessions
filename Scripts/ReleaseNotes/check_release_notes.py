#!/usr/bin/env python3
"""Check release-note style and preview the candidate version before tagging."""

import argparse

from catalog import SECTION_TITLES, load_catalog, release_for_tag


def check_release_notes(tag=None):
    releases = load_catalog()
    if tag is None:
        print(f"Release-note editorial checks passed for {len(releases)} versions.")
        return
    release = release_for_tag(releases, tag)
    if release != releases[0]:
        raise ValueError(f"{tag} must be the newest entry before tagging a release.")
    print(f"Release-note editorial checks passed for {tag}.\n")
    print(f'{tag} — {release["title"]["en"]} / {release["title"]["zh-Hans"]}')
    for section in release["sections"]:
        print(f'\n{SECTION_TITLES[section["kind"]]}')
        for item in section["items"]:
            print(f'- {item["en"]}\n  {item["zh-Hans"]}')
    print("\nBefore tagging: review each claim against the changes since the previous release.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag")
    arguments = parser.parse_args()
    try:
        check_release_notes(arguments.tag)
    except ValueError as error:
        parser.exit(1, f"Release-note check failed: {error}\n")
