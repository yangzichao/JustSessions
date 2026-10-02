#!/usr/bin/env python3
"""Compile the authoritative String Catalog into checked-in SwiftPM localization resources."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from catalog_validation import validate_catalog

PROJECT_DIRECTORY = Path(__file__).resolve().parents[2]
CATALOG_PATH = PROJECT_DIRECTORY / 'Localization/Localizable.xcstrings'
RESOURCE_DIRECTORY = PROJECT_DIRECTORY / 'Sources/JustSessions/Resources/Localization'


def compile_catalog(check_only=False):
    catalog = json.loads(CATALOG_PATH.read_text())
    errors = validate_catalog(catalog)
    if errors:
        raise SystemExit('\n'.join(errors))
    with tempfile.TemporaryDirectory(prefix='justsessions-localizations-') as temporary_directory:
        output_directory = Path(temporary_directory)
        # Xcode can omit development-language files because source literals provide them. SwiftPM and the
        # runtime language picker need an explicit resource for that language, so materialize it here.
        for key, entry in catalog['strings'].items():
            entry.setdefault('localizations', {}).setdefault(catalog['sourceLanguage'], {
                'stringUnit': {'state': 'translated', 'value': key}
            })
        compiler_input = output_directory / CATALOG_PATH.name
        compiler_input.write_text(json.dumps(catalog, ensure_ascii=False))
        subprocess.run(['xcrun', 'xcstringstool', 'compile', str(compiler_input), '--output-directory', temporary_directory], check=True)
        compiler_input.unlink()
        generated_files = {path.relative_to(output_directory): path.read_bytes() for path in output_directory.rglob('*') if path.is_file()}
        saved_files = {path.relative_to(RESOURCE_DIRECTORY): path.read_bytes() for path in RESOURCE_DIRECTORY.rglob('*') if path.is_file()}
        if check_only:
            if generated_files != saved_files:
                raise SystemExit('Localization resources are out of date. Run make localization after editing the String Catalog.')
        elif generated_files != saved_files:
            RESOURCE_DIRECTORY.mkdir(parents=True, exist_ok=True)
            for localization_directory in RESOURCE_DIRECTORY.glob('*.lproj'):
                shutil.rmtree(localization_directory)
            for relative_path, content in generated_files.items():
                destination = RESOURCE_DIRECTORY / relative_path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(content)
    print('Localization catalog and compiled resources passed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    compile_catalog(parser.parse_args().check)
