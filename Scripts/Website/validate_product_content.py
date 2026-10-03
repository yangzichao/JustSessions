"""Reject capability claims that differ from the app's provider and transcript switches."""

from pathlib import Path

from app_capabilities import read_app_capabilities
from capability_table import CapabilityTable
from homepage_capabilities import validate_homepage_capabilities


def validate_support_cell(cell, expected_support, location, capability):
    has_cli_alternative = capability == "branch" and any(command in cell for command in ("/fork", "/rewind"))
    assert cell in ("Yes", "No", "Not yet") or has_cli_alternative, f"Unknown support wording: {location}: {cell}"
    assert (cell == "Yes") == expected_support, f"App and documentation differ: {location}: {cell}"


def markdown_rows(document_content):
    return [[cell.strip() for cell in line.strip().strip("|").split("|")] for line in document_content.splitlines() if line.startswith("|")]


def validate_product_content(repository_directory: Path):
    capabilities = read_app_capabilities(repository_directory)
    provider_identifiers = list(capabilities)
    homepage_content = (repository_directory / "website/index.html").read_text()
    guide_content = (repository_directory / "website/guide.html").read_text()
    guide_table = CapabilityTable()
    guide_table.feed(guide_content)
    assert list(guide_table.rows) == provider_identifiers, "Guide provider rows differ from the app"
    for identifier, support in capabilities.items():
        cells = guide_table.rows[identifier]
        assert len(cells) == 5, f"Guide needs four capability cells: {identifier}"
        assert support["name"] in cells[0] and guide_table.commands[identifier] == support["command"], f"Guide CLI name or command differs: {identifier}"
        assert f"<span>{support['name']}" in homepage_content, f"Homepage is missing a supported CLI: {identifier}"
        for column_index, capability in enumerate(("preview", "branch", "ssh", "delete"), start=1):
            validate_support_cell(cells[column_index].strip(), support[capability], f"guide.html {identifier} {capability}", capability)

    readme_rows = markdown_rows((repository_directory / "README.md").read_text())
    expected_rows = {
        "Read a conversation preview": "preview",
        "Branch a conversation from the app": "branch",
        "Browse and manage sessions over SSH": "ssh",
        "Delete sessions from the app": "delete",
    }
    capability_rows = [row for row in readme_rows if row[0] in expected_rows]
    matched_rows = {row[0]: row for row in capability_rows}
    assert len(capability_rows) == len(expected_rows), "README capability rows are missing or duplicated"
    assert set(matched_rows) == set(expected_rows), "README capability rows are missing"
    headers = [row for row in readme_rows if row[0] == "Capability"]
    assert len(headers) == 1, "README needs one capability header"
    header = headers[0]
    assert len(header) == len(capabilities) + 1, "README provider count differs from the app"
    for column_index, support in enumerate(capabilities.values(), start=1):
        assert support["name"] in header[column_index], "README provider order differs from the app"
        for row_name, capability in expected_rows.items():
            row = matched_rows[row_name]
            assert len(row) == len(header), f"Incomplete README row: {row_name}"
            validate_support_cell(row[column_index], support[capability], f"README {support['name']} {capability}", capability)

    storage_rows = markdown_rows((repository_directory / "docs/guides/session-storage.md").read_text())[2:]
    assert len(storage_rows) == len(capabilities), "Storage guide provider count differs from the app"
    for row, support in zip(storage_rows, capabilities.values()):
        assert len(row) == 5 and support["name"] in row[0], "Storage guide provider order differs from the app"
        for column_index, capability in enumerate(("preview", "branch", "delete"), start=2):
            validate_support_cell(row[column_index], support[capability], f"storage guide {support['name']} {capability}", capability)
    validate_homepage_capabilities(homepage_content, capabilities)
    print(f"Product content validation passed: {len(capabilities)} CLIs, homepage capability claims, guide commands, and preview/branch/SSH/deletion tables.")


if __name__ == "__main__":
    validate_product_content(Path(__file__).resolve().parents[2])
