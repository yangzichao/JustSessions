#!/bin/sh
# Fails when Periphery finds unused Swift: declarations, parameters, imports, or properties only ever assigned.
# Periphery reads an index store; Swift Build, the default build system, writes none, so this builds the package and its
# tests with the native build system into .build/periphery, apart from the development build. SwiftPM warns that the
# native build system is deprecated; the check still works.
set -eu

if ! command -v periphery >/dev/null 2>&1; then
    echo "Periphery is not installed. Install it with: brew install periphery" >&2
    exit 1
fi

scratch_path=".build/periphery"
index_store_path="$PWD/$scratch_path/index"

swift build --build-tests --build-system native --scratch-path "$scratch_path" \
    -Xswiftc -index-store-path -Xswiftc "$index_store_path"

if ! periphery scan --config .periphery.yml --skip-build --index-store-path "$index_store_path" --quiet; then
    echo "Periphery found unused code. Delete it, or mark code only reflection or a \$ binding reaches with" >&2
    echo "// periphery:ignore and a reason; see docs/development/build-and-release.md#dead-code." >&2
    exit 1
fi
echo "Dead code check passed."
