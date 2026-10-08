"""Read the one release catalog used by the native app and publication tools."""

import json
import re
from datetime import date
from pathlib import Path

from editorial_checks import validate_release_editorial_standard

REPOSITORY_DIRECTORY = Path(__file__).resolve().parents[2]
CATALOG_PATH = REPOSITORY_DIRECTORY / "Sources/JustSessions/Resources/ReleaseNotes/releases.json"
WEBSITE_URL = "https://yangzichao.github.io/JustSessions/release-notes.html"
RELEASE_URL = "https://github.com/yangzichao/JustSessions/releases/tag/v"
SECTION_TITLES = {"new": "New", "improved": "Improved", "fixed": "Fixed"}
VERSION_PATTERN = re.compile(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")


def validate_text(text):
    if not isinstance(text, dict) or set(text) != {"en", "zh-Hans"}:
        raise ValueError("Release copy needs English and Simplified Chinese translations.")
    for value in text.values():
        if not isinstance(value, str) or not value.strip() or "\n" in value or "\r" in value:
            raise ValueError("Release copy must be a nonempty single line.")


def load_catalog(path=CATALOG_PATH):
    releases = json.loads(path.read_text())
    if not isinstance(releases, list) or not releases:
        raise ValueError("Release history must contain at least one release.")
    previous_version = None
    previous_date = None
    for release in releases:
        if set(release) != {"version", "publishedOn", "title", "sections"}:
            raise ValueError("Release entries need version, publishedOn, title, and sections.")
        version = release["version"]
        if not isinstance(version, str) or not VERSION_PATTERN.fullmatch(version):
            raise ValueError(f"Invalid release version: {version}")
        version_components = tuple(map(int, version.split(".")))
        if previous_version is not None and version_components >= previous_version:
            raise ValueError("Release versions must be unique and ordered newest first.")
        release_date = date.fromisoformat(release["publishedOn"])
        if release_date.isoformat() != release["publishedOn"]:
            raise ValueError("Release dates must use YYYY-MM-DD.")
        if previous_date is not None and release_date > previous_date:
            raise ValueError("Release dates must be ordered newest first.")
        previous_version, previous_date = version_components, release_date
        validate_text(release["title"])
        if not isinstance(release["sections"], list) or not release["sections"]:
            raise ValueError(f"Release {version} needs user-facing changes.")
        section_kinds = set()
        for section in release["sections"]:
            if set(section) != {"kind", "items"} or section["kind"] not in SECTION_TITLES:
                raise ValueError("Release sections must be new, improved, or fixed.")
            if section["kind"] in section_kinds:
                raise ValueError("A release must not repeat a section.")
            section_kinds.add(section["kind"])
            if not isinstance(section["items"], list) or not section["items"]:
                raise ValueError("Release sections must contain changes.")
            for item in section["items"]:
                validate_text(item)
        validate_release_editorial_standard(release)
    return releases


def release_for_tag(releases, tag):
    for release in releases:
        if tag == "v" + release["version"]:
            return release
    raise ValueError(f"Add curated release notes for {tag} to {CATALOG_PATH.relative_to(REPOSITORY_DIRECTORY)} before publishing.")
