#!/usr/bin/env python3
"""Let Swift's compiler extract UI strings; sync them with the Xcode String Catalog."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from compile_catalog import CATALOG_PATH, PROJECT_DIRECTORY, compile_catalog


def sync_catalog(check_only=False):
    extraction_directory = PROJECT_DIRECTORY / '.build/localization-extraction'
    extraction_directory.mkdir(parents=True, exist_ok=True)
    # Keep compiler outputs between incremental builds. Removed Swift files are excluded below.
    subprocess.run(['swift', 'build', '-Xswiftc', '-emit-localized-strings', '-Xswiftc', '-emit-localized-strings-path',
                    '-Xswiftc', str(extraction_directory)], cwd=PROJECT_DIRECTORY, check=True)
    source_paths = sorted((PROJECT_DIRECTORY / 'Sources/JustSessions').rglob('*.swift'))
    source_names = [source_path.stem for source_path in source_paths]
    if len(source_names) != len(set(source_names)):
        raise SystemExit('Localization extraction requires unique Swift source filenames. Rename duplicate files.')
    stringsdata_files = [extraction_directory / (source_path.stem + '.stringsdata') for source_path in source_paths]
    missing_files = [path for path in stringsdata_files if not path.is_file()]
    if missing_files:
        raise SystemExit(f'Compiler extraction is incomplete: {missing_files}. Remove .build and retry.')
    for source_path, stringsdata_path in zip(source_paths, stringsdata_files):
        extracted_source = Path(json.loads(stringsdata_path.read_text())['source'])
        if extracted_source.resolve() != source_path.resolve():
            raise SystemExit(f'Localization extraction for {source_path} was overwritten by {extracted_source}. Use a unique filename.')
    with tempfile.TemporaryDirectory(prefix='justsessions-catalog-') as temporary_directory:
        synced_catalog = Path(temporary_directory) / CATALOG_PATH.name
        shutil.copyfile(CATALOG_PATH, synced_catalog)
        subprocess.run(['xcrun', 'xcstringstool', 'sync', str(synced_catalog), '--stringsdata',
                        *(str(path) for path in stringsdata_files)], check=True)
        if check_only:
            old_strings = json.loads(CATALOG_PATH.read_text())['strings']
            new_strings = json.loads(synced_catalog.read_text())['strings']
            missing_keys = sorted(set(new_strings) - set(old_strings))
            stale_keys = sorted(key for key, entry in new_strings.items() if entry.get('extractionState') == 'stale')
            changed_keys = sorted(key for key in set(new_strings) & set(old_strings) if old_strings[key] != new_strings[key])
            if missing_keys or stale_keys or changed_keys:
                raise SystemExit(f'Run make localization. Missing strings: {missing_keys}; stale strings: {stale_keys}; changed source entries: {changed_keys}')
        else:
            shutil.copyfile(synced_catalog, CATALOG_PATH)
    compile_catalog(check_only=check_only)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    sync_catalog(parser.parse_args().check)
