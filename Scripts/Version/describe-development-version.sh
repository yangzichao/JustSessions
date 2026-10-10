#!/bin/zsh
set -euo pipefail

# Prints the version a local build shows, as `git describe` writes it without the tag's "v": such as 1.1.0-3-gf45492c,
# three commits after v1.1.0 at f45492c, ending in -dirty when tracked files have changed. Release builds take
# APP_VERSION from their tag instead. Settings, feedback, and crash reports show this version, so they tell a
# development build apart from the release it started from. The update check counts keep only X.Y.Z versions, and
# feedback accepts only letters, digits, spaces, dots, hyphens, and parentheses, so the format must not change.
project_directory="${0:A:h:h:h}"
release_tag_pattern='v[0-9]*.[0-9]*.[0-9]*'
description="$(git -C "$project_directory" describe --tags --long --dirty --always --match "$release_tag_pattern")"

if [[ "$description" =~ '^v([0-9]+\.[0-9]+\.[0-9]+-[0-9]+-g[0-9a-f]+(-dirty)?)$' ]]; then
    print -r -- "${match[1]}"
elif [[ "$description" =~ '^[0-9a-f]+(-dirty)?$' ]]; then
    # No release tag is reachable, such as in a shallow clone, so `git describe` printed the commit alone.
    print -r -- "0.0.0-g$description"
else
    print -u2 "Unexpected git describe output: $description"
    exit 1
fi
