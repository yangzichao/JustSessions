"""Render editorial text safely for the website, GitHub, and Sparkle."""

from datetime import date
from html import escape

from catalog import RELEASE_URL, SECTION_TITLES, WEBSITE_URL


def readable_date(release):
    published = date.fromisoformat(release["publishedOn"])
    return f"{published.strftime('%B')} {published.day}, {published.year}"


def render_sections(release):
    sections = []
    for section in release["sections"]:
        items = "".join(f"<li>{escape(item['en'])}</li>" for item in section["items"])
        sections.append(f'<section class="release-changes"><h3>{SECTION_TITLES[section["kind"]]}</h3><ul>{items}</ul></section>')
    return "\n".join(sections)


def render_website_history(releases):
    entries = []
    for index, release in enumerate(releases):
        version = release["version"]
        heading_id = f"release-{version}"
        badge = '<span class="release-latest">Latest</span>' if index == 0 else ""
        entries.append(
            f'<article class="release-entry" id="v{version}" aria-labelledby="{heading_id}">\n'
            f'  <div class="release-meta"><a class="release-version" href="#v{version}">v{version}</a>{badge}'
            f'<time datetime="{release["publishedOn"]}">{readable_date(release)}</time></div>\n'
            f'  <h2 id="{heading_id}">{escape(release["title"]["en"])}</h2>\n'
            f'  {render_sections(release)}\n'
            f'  <a class="release-download" href="{RELEASE_URL}{version}">Download v{version} <span aria-hidden="true">↗</span></a>\n'
            '</article>'
        )
    return "\n".join(entries)


def markdown_text(value):
    for character in ("\\", "*", "_", "[", "]", "<", ">", "`"):
        value = value.replace(character, "\\" + character)
    return value


def render_markdown(release):
    lines = [f'## {markdown_text(release["title"]["en"])}', "", readable_date(release), ""]
    for section in release["sections"]:
        lines.extend([f'### {SECTION_TITLES[section["kind"]]}', ""])
        lines.extend(f'- {markdown_text(item["en"])}' for item in section["items"])
        lines.append("")
    lines.extend([
        f"[Full release history]({WEBSITE_URL})", "",
        "Install by opening JustSessions.dmg and dragging JustSessions into Applications.",
        "The app is signed and notarized. Local tmux is included; SSH hosts need their own tmux.", "",
    ])
    return "\n".join(lines)


def render_sparkle_html(release):
    return (
        '<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f'<title>JustSessions {release["version"]}</title>'
        '<style>body{font:14px -apple-system,sans-serif;line-height:1.6;margin:20px}'
        'h1{font-size:21px}h3{font-size:14px;margin-bottom:6px}ul{padding-left:22px}'
        'li{margin-bottom:6px}@media(prefers-color-scheme:dark){body{color:#eee;background:#222}}</style>'
        '</head><body>'
        f'<h1>{escape(release["title"]["en"])}</h1>'
        f'<p>Version {release["version"]} · {readable_date(release)}</p>'
        f'{render_sections(release)}<p><a href="{WEBSITE_URL}">Full release history</a></p>'
        '</body></html>\n'
    )
