#!/bin/zsh
set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h:h}"
source "$script_directory/versions.sh"
source "$script_directory/build-helpers.sh"

build_architecture="$(uname -m)"
compiler_sdk_directory="$(xcrun --sdk macosx --show-sdk-path)"
build_directory="$project_directory/.build/Tmux/$build_architecture"
downloads_directory="$project_directory/.build/Tmux/downloads"
sources_directory="$build_directory/sources"
prefix_directory="$build_directory/prefix"
runtime_directory="$build_directory/runtime"
build_jobs="$(sysctl -n hw.ncpu)"
build_fingerprint="$(cat "$script_directory/"*.sh "$script_directory/"*.py | shasum -a 256 | awk '{print $1}')-$build_architecture-$compiler_sdk_directory"

if [[ -f "$runtime_directory/build-fingerprint" ]] \
    && [[ "$(cat "$runtime_directory/build-fingerprint")" == "$build_fingerprint" ]] \
    && [[ -x "$runtime_directory/bin/tmux" ]]; then
    python3 "$script_directory/verify-runtime.py" "$runtime_directory"
    print "$runtime_directory"
    exit 0
fi

rm -rf "$sources_directory" "$prefix_directory" "$runtime_directory"
mkdir -p "$downloads_directory" "$sources_directory" "$prefix_directory/lib" "$prefix_directory/include"
export CC=/usr/bin/clang
# The runtime must run on the app's oldest supported macOS, even when the SDK is newer. An API newer than
# the deployment target becomes a weak import that is NULL on older macOS, so calling one fails the build.
export CFLAGS="-O2 -arch $build_architecture -isysroot $compiler_sdk_directory -mmacosx-version-min=$macos_deployment_target -Werror=unguarded-availability-new"
export LDFLAGS="-arch $build_architecture -isysroot $compiler_sdk_directory -mmacosx-version-min=$macos_deployment_target"
# Upstream build utilities also use CPPFLAGS, which must not inherit Homebrew paths.
export CPPFLAGS=""
export PKG_CONFIG=/usr/bin/false

download_source "libevent-$libevent_version" "$libevent_checksum" \
    "https://github.com/libevent/libevent/releases/download/release-$libevent_version/libevent-$libevent_version.tar.gz"
download_source "ncurses-$ncurses_version" "$ncurses_checksum" \
    "https://ftp.gnu.org/gnu/ncurses/ncurses-$ncurses_version.tar.gz" \
    "https://ftpmirror.gnu.org/gnu/ncurses/ncurses-$ncurses_version.tar.gz" \
    "https://invisible-mirror.net/archives/ncurses/ncurses-$ncurses_version.tar.gz"
download_source "utf8proc-$utf8proc_version" "$utf8proc_checksum" \
    "https://github.com/JuliaStrings/utf8proc/releases/download/v$utf8proc_version/utf8proc-$utf8proc_version.tar.gz"
download_source "tmux-$tmux_version" "$tmux_checksum" \
    "https://github.com/tmux/tmux/releases/download/$tmux_version/tmux-$tmux_version.tar.gz"

build_dependency libevent build_libevent
build_dependency ncurses build_ncurses
build_dependency utf8proc build_utf8proc
build_dependency tmux build_tmux

mkdir -p "$runtime_directory/bin" "$runtime_directory/share" "$runtime_directory/licenses"
cp "$sources_directory/tmux-$tmux_version/tmux" "$runtime_directory/bin/tmux"
# Ship the terminal types used by the embedded terminal and tmux, with system fallback for other types.
"$prefix_directory/bin/tic" -x -e ansi,dumb,screen,screen-256color,tmux,tmux-256color,xterm,xterm-256color \
    -o "$runtime_directory/share/terminfo" "$sources_directory/ncurses-$ncurses_version/misc/terminfo.src"
cp "$sources_directory/libevent-$libevent_version/LICENSE" "$runtime_directory/licenses/libevent.txt"
cp "$sources_directory/ncurses-$ncurses_version/COPYING" "$runtime_directory/licenses/ncurses.txt"
cp "$sources_directory/utf8proc-$utf8proc_version/LICENSE.md" "$runtime_directory/licenses/utf8proc.txt"
python3 "$script_directory/collect-source-notices.py" "$sources_directory/tmux-$tmux_version" "$runtime_directory/licenses/tmux.txt"
cp "$script_directory/versions.sh" "$runtime_directory/versions.txt"
python3 "$script_directory/verify-runtime.py" "$runtime_directory"
print -r -- "$build_fingerprint" > "$runtime_directory/build-fingerprint"
print "$runtime_directory"
