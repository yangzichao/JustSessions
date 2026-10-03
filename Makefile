.DEFAULT_GOAL := build

# Swift and tmux targets share build directories, including when multiple goals use -j.
.NOTPARALLEL:

APP_BUNDLE_PATH ?= dist/JustSessions.app
INSTALLER_PATH ?= dist/JustSessions.dmg

.PHONY: build dev run check test verify dmg website localization localization-check help

build:
	./Scripts/build-app.sh "$(APP_BUNDLE_PATH)"

dev run: build
	./Scripts/open-dev-app.sh "$(APP_BUNDLE_PATH)"

check:
	swift build

test:
	@runtime_directory="$$(./Scripts/Tmux/build-runtime.sh)" && \
	JUSTSESSIONS_TEST_TMUX_RUNTIME="$$runtime_directory" swift test

# CI runs only the tests; run this before opening a pull request, pushing to main, or tagging a release.
verify: test localization-check build
	./Scripts/Release/check-app-launches.sh "$(APP_BUNDLE_PATH)"

dmg: build
	./Scripts/build-dmg.sh "$(APP_BUNDLE_PATH)" "$(INSTALLER_PATH)"

website:
	python3 Scripts/Website/build_site.py

localization:
	python3 Scripts/Localization/sync_catalog.py

localization-check:
	python3 Scripts/Localization/sync_catalog.py --check
	python3 -m unittest discover -s Scripts/Localization/tests

help:
	@printf '%s\n' \
		'make           Build dist/JustSessions.app with bundled tmux' \
		'make dev       Build the app, quit its running copy, and open it' \
		'make run       Alias for make dev' \
		'make check     Compile the Swift development build' \
		'make test      Build bundled tmux and run the Swift tests' \
		'make verify    Run the tests, localization checks, and check the built app opens' \
		'make dmg       Build the app and dist/JustSessions.dmg' \
		'make website   Build and validate the product website' \
		'make localization        Extract UI strings and compile translations' \
		'make localization-check  Check UI strings, translations, and resources' \
		'Override output paths with APP_BUNDLE_PATH=... and INSTALLER_PATH=...'
