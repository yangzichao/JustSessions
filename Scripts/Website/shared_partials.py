"""Insert site-wide markup, the top bar and the footer, into every page at build time.

A page asks for a partial with a line like `<!-- partial: site-header -->`. The build replaces it with
`website/partials/site-header.html`, indented to match, and marks the links to the current page.
"""

import re

PARTIAL_PLACEHOLDER_PATTERN = re.compile(r"^(?P<indentation> *)<!-- partial: (?P<partial_name>[\w-]+) -->$", re.MULTILINE)
PAGES_WITH_SHARED_PARTIALS = ("index.html", "guide.html")
# Each shared partial: the element only it may define, and a readable name for errors.
SHARED_PARTIALS = {"site-header": ("<header", "top bar"), "site-footer": ("<footer", "footer")}


def validate_partial_placeholders(source_directory):
    for document_name in PAGES_WITH_SHARED_PARTIALS:
        document_content = (source_directory / document_name).read_text()
        placeholders = [match["partial_name"] for match in PARTIAL_PLACEHOLDER_PATTERN.finditer(document_content)]
        for partial_name, (owned_element, readable_name) in SHARED_PARTIALS.items():
            assert placeholders.count(partial_name) == 1, f"{document_name} must include the shared {readable_name} exactly once"
            assert owned_element not in document_content, f"{document_name} must not define its own {readable_name}; use the {partial_name} partial"
            assert f'"./styles/{partial_name}.css"' in document_content, f"{document_name} must load styles/{partial_name}.css"


def mark_current_page(partial_content, document_name):
    return partial_content.replace(f'href="./{document_name}"', f'href="./{document_name}" aria-current="page"')


def insert_shared_partials(document_path, partial_directory):
    def render_partial(match):
        partial_path = partial_directory / f"{match['partial_name']}.html"
        assert partial_path.is_file(), f"Missing website partial: {partial_path.name}"
        partial_content = mark_current_page(partial_path.read_text().rstrip("\n"), document_path.name)
        return "\n".join(match["indentation"] + line if line else line for line in partial_content.split("\n"))

    document_content = PARTIAL_PLACEHOLDER_PATTERN.sub(render_partial, document_path.read_text())
    assert "<!-- partial:" not in document_content, f"Unresolved partial placeholder in {document_path.name}"
    document_path.write_text(document_content)
