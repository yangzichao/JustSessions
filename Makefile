.DEFAULT_GOAL := build

# Swift and tmux targets share build directories, including when multiple goals use -j.
.NOTPARALLEL:

APP_BUNDLE_PATH ?= dist/JustSessions.app
INSTALLER_PATH ?= dist/JustSessions.dmg

.PHONY: build run check test dmg website help

build:
	./Scripts/build-app.sh "$(APP_BUNDLE_PATH)"

run: build
	open "$(APP_BUNDLE_PATH)"

check:
	swift build

test:
	@runtime_directory="$$(./Scripts/Tmux/build-runtime.sh)" && \
	JUSTSESSIONS_TEST_TMUX_RUNTIME="$$runtime_directory" swift test

dmg: build
	./Scripts/build-dmg.sh "$(APP_BUNDLE_PATH)" "$(INSTALLER_PATH)"

website:
	python3 Scripts/Website/build_site.py

help:
	@printf '%s\n' \
		'make           Build dist/JustSessions.app with bundled tmux' \
		'make run       Build and open the app' \
		'make check     Compile the Swift development build' \
		'make test      Build bundled tmux and run the Swift tests' \
		'make dmg       Build the app and dist/JustSessions.dmg' \
		'make website   Build and validate the product website' \
		'Override output paths with APP_BUNDLE_PATH=... and INSTALLER_PATH=...'
