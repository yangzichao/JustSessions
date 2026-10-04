"""Version local ES module imports before hashing their parent scripts."""

import hashlib
import re
from urllib.parse import parse_qs, urlparse

SCRIPT_IMPORT_PATTERN = re.compile(r'\bfrom\s+"(\.[^"\n]+\.js(?:\?[^"\n]*)?)"')


def version_script_imports(script_directory):
    completed = set()
    visiting = set()

    def version_script(script_path):
        if script_path in completed:
            return
        assert script_path not in visiting, f"Circular website script import: {script_path.name}"
        visiting.add(script_path)

        def version_reference(match):
            reference = urlparse(match[1])
            dependency_path = (script_path.parent / reference.path).resolve()
            assert dependency_path.is_relative_to(script_directory.resolve()), "Script import leaves script directory"
            assert dependency_path.is_file(), f"Missing script import: {match[1]}"
            version_script(dependency_path)
            dependency_version = hashlib.sha256(dependency_path.read_bytes()).hexdigest()[:12]
            return f'from "{reference.path}?v={dependency_version}"'

        script_path.write_text(SCRIPT_IMPORT_PATTERN.sub(version_reference, script_path.read_text()))
        visiting.remove(script_path)
        completed.add(script_path)

    for script_path in script_directory.rglob("*.js"):
        version_script(script_path.resolve())


def validate_script_imports(website_directory):
    for script_path in (website_directory / "scripts").rglob("*.js"):
        for match in SCRIPT_IMPORT_PATTERN.finditer(script_path.read_text()):
            reference = urlparse(match[1])
            dependency_path = (script_path.parent / reference.path).resolve()
            assert dependency_path.is_relative_to(website_directory.resolve()), "Script import leaves published directory"
            assert dependency_path.is_file(), f"Missing script import: {match[1]}"
            expected_version = hashlib.sha256(dependency_path.read_bytes()).hexdigest()[:12]
            assert parse_qs(reference.query).get("v") == [expected_version], f"Script import cache version mismatch: {match[1]}"
