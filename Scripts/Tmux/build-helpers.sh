# Sourced by build-runtime.sh; all paths are private build directories.
# Tries each URL in order, so one unreachable host does not fail the build; the checksum pins the archive.
download_source() {
    local source_name="$1" expected_checksum="$2"
    shift 2
    local archive_path="$downloads_directory/$source_name.tar.gz"
    if [[ ! -f "$archive_path" ]]; then
        local source_url
        for source_url in "$@"; do
            if curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 \
                "$source_url" --output "$archive_path.partial"; then
                mv "$archive_path.partial" "$archive_path"
                break
            fi
            print -u2 "Download failed: $source_url"
        done
        if [[ ! -f "$archive_path" ]]; then
            rm -f "$archive_path.partial"
            print -u2 "No source reachable for $source_name"
            return 1
        fi
    fi
    local actual_checksum="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
    if [[ "$actual_checksum" != "$expected_checksum" ]]; then
        print -u2 "Checksum mismatch: $archive_path"
        return 1
    fi
    tar -xzf "$archive_path" -C "$sources_directory"
}

build_dependency() {
    local dependency_name="$1"
    shift
    print -u2 "Building $dependency_name…"
    local log_path="$build_directory/$dependency_name.log"
    if ! ( "$@" ) >"$log_path" 2>&1; then
        tail -n 60 "$log_path" >&2
        return 1
    fi
}

build_libevent() {
    cd "$sources_directory/libevent-$libevent_version"
    # configure's link test finds pipe2() in the macOS 27 SDK, but earlier macOS lacks it and tmux would crash
    # calling the NULL weak import. Without pipe2(), libevent uses pipe() and fcntl() instead.
    ac_cv_func_pipe2=no ./configure --prefix="$prefix_directory" --disable-shared --enable-static \
        --disable-openssl --disable-samples --disable-libevent-regress
    make -j "$build_jobs"
    make install
}

build_ncurses() {
    cd "$sources_directory/ncurses-$ncurses_version"
    ./configure --prefix="$prefix_directory" --without-shared --with-normal --without-debug \
        --enable-widec --without-cxx --without-cxx-binding --without-ada --without-tests \
        --without-manpages --with-default-terminfo-dir=/usr/share/terminfo \
        --with-terminfo-dirs=/usr/share/terminfo:/etc/terminfo
    make -j "$build_jobs"
    # Avoid baking a build-tree terminal database into the runtime, or installing anything into /usr/share.
    make install.libs install.includes
    mkdir -p "$prefix_directory/bin"
    cp progs/tic "$prefix_directory/bin/tic"
}

build_utf8proc() {
    cd "$sources_directory/utf8proc-$utf8proc_version"
    make -j "$build_jobs" libutf8proc.a
    cp libutf8proc.a "$prefix_directory/lib/"
    cp utf8proc.h "$prefix_directory/include/"
}

build_tmux() {
    cd "$sources_directory/tmux-$tmux_version"
    # Explicit static archive paths prevent a developer's Homebrew libraries entering the app.
    LIBEVENT_CORE_CFLAGS="-I$prefix_directory/include" \
    LIBEVENT_CORE_LIBS="$prefix_directory/lib/libevent_core.a" \
    LIBNCURSESW_CFLAGS="-I$prefix_directory/include/ncursesw" \
    LIBNCURSESW_LIBS="$prefix_directory/lib/libncursesw.a" \
    LIBUTF8PROC_CFLAGS="-I$prefix_directory/include" \
    LIBUTF8PROC_LIBS="$prefix_directory/lib/libutf8proc.a" \
    PKG_CONFIG=/usr/bin/false \
        ./configure --prefix="$prefix_directory" --enable-utf8proc --disable-jemalloc \
            --disable-utempter --with-TERM=tmux-256color
    make -j "$build_jobs"
    /usr/bin/strip tmux
}
