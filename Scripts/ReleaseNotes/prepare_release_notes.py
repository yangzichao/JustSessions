#!/usr/bin/env python3
"""Require curated notes for a tag and write the GitHub/Sparkle publication inputs."""

import argparse
from pathlib import Path

from catalog import load_catalog, release_for_tag
from render_notes import render_markdown, render_sparkle_html


def prepare_release_notes(tag, output_directory):
    release = release_for_tag(load_catalog(), tag)
    output_directory.mkdir(parents=True, exist_ok=True)
    (output_directory / "release-notes.md").write_text(render_markdown(release))
    # Sparkle discovers the notes by matching this name with JustSessions.zip.
    (output_directory / "JustSessions.html").write_text(render_sparkle_html(release))
    print(f"Prepared curated release notes for {tag}: {output_directory}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("--output-directory", type=Path, required=True)
    arguments = parser.parse_args()
    prepare_release_notes(arguments.tag, arguments.output_directory)
