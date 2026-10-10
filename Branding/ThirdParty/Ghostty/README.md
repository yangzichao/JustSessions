# Ghostty's terminal and what it links

The Ghostty terminal engine comes from [libghostty-spm](https://github.com/Lakr233/libghostty-spm) `2.2.2026100901`, a prebuilt `libghostty.a` built from Ghostty commit [`35a81a98`](https://github.com/ghostty-org/ghostty/tree/35a81a980bb9fce09a1ea762a68b55f8eb3477ed) with Zig 0.16.0. That archive statically links the components below, and each one's license text is in this folder, unmodified from the pinned upstream source. `manifest.json` records each component's version, source URL, the file's SHA-256, and the evidence for the version. `Scripts/build-app.sh` copies this folder into the app as `Contents/Resources/Ghostty-Licenses`.

| Component | Version | License | File |
| --- | --- | --- | --- |
| Ghostty | 1.3.2-dev at `35a81a98` | MIT | `ghostty.txt` |
| libghostty-spm (Swift wrapper and `libcxx-verbose-abort-compat.o`) | 2.2.2026100901 | MIT | `libcxx-compat.txt` |
| Zig `compiler_rt` and standard library | 0.16.0 | MIT | `zig-compiler-rt.txt` |
| Oniguruma | 6.9.9 | BSD-2-Clause | `oniguruma.txt` |
| FreeType | 2.13.2 | FreeType License (FTL), with the BDF and PCF drivers' own notices | `freetype.txt`, `freetype-LICENSE.txt`, `freetype-bdf-README.txt`, `freetype-pcf-README.txt` |
| libpng | 1.6.43 | libpng-2.0 | `libpng.txt` |
| zlib | 1.3.1 | Zlib | `zlib.txt` |
| GNU libintl (gettext-runtime) | gettext 0.24 | LGPL-2.1-or-later | `libintl.txt` |
| simdutf | 9.0.0 | Apache-2.0 OR MIT | `simdutf.txt`, `simdutf-LICENSE-APACHE.txt` |
| Google Highway | 1.2.0 at `66486a10` | Apache-2.0 OR BSD-3-Clause | `highway.txt`, `highway-LICENSE-BSD3.txt` |
| Wuffs | 0.4.0-alpha.10 at `7411f488` | Apache-2.0 OR MIT | `wuffs.txt` |
| stb_image, stb_image_resize | 2.28, 0.97 | MIT OR Unlicense | `stb.txt` (the license block of `stb_image.h`) |
| z2d | 0.12.1 at `7dbae85c` | MPL-2.0 | `z2d.txt`, `z2d-COPYING-MPL-2.0.txt` |
| libvaxis | 0.6.0 | MIT | `vaxis.txt` |
| libxev | `9ce8e8e6` | MIT | `libxev.txt` |
| zig-objc | `c8de82ff` | MIT | `zig-objc.txt` |
| uucode | 0.2.0 | MIT AND Unicode-3.0 | `uucode.txt`, `uucode-LICENSE_unicode.txt`, `uucode-LICENSE_Bjoern_Hoehrmann.txt` |
| zf | 0.11.0 | MIT | `zf.txt` |
| JetBrains Mono, Ghostty's built-in font | 2.304 | OFL-1.1 | `jetbrains-mono.txt` |
| Symbols Nerd Font, Ghostty's built-in symbols | 3.4.0 | MIT; each glyph set keeps its own license | `nerd-fonts-symbols.txt`, `nerd-fonts-license-audit.md`, `nerd-fonts-glyphs/` |

Portions of this software are copyright © 2023 The FreeType Project (www.freetype.org). All rights reserved.

## Open obligations

Two licenses ask for more than shipping their text. Both are recorded here for review before a release that includes Ghostty's terminal:

- **GNU libintl, LGPL-2.1-or-later.** Statically linked code under the LGPL must let users relink the app with a modified library (section 6), for example by providing the object files, along with the library's source or a written offer for it. The source is gettext 0.24 (`https://deps.files.ghostty.org/gettext-0.24.tar.gz`) with Ghostty's `pkg/libintl` build files at the commit above.
- **z2d, MPL-2.0.** The source of the MPL-covered files must be available to recipients: z2d at commit [`7dbae85c`](https://github.com/vancluever/z2d/tree/7dbae85c81784dba9988320bf9543ed9a81350c8).

Not collected: license texts for the Devicons, Font Logos, and Seti-UI glyph sets in Symbols Nerd Font (`nerd-fonts-license-audit.md` lists them as MIT, Unlicense, and MIT), and for the X11 `rgb.txt` color names Ghostty embeds (MIT/X11).

Recheck this folder whenever `Package.swift` moves libghostty-spm to another release: the archive's members show what it links (`lipo -thin arm64 libghostty.a -output /tmp/a.a && ar -t /tmp/a.a`).
