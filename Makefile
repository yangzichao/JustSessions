.DEFAULT_GOAL := build

# Swift and tmux targets share build directories, including when multiple goals use -j.
.NOTPARALLEL:

APP_BUNDLE_PATH ?= dist/JustSessions.app
INSTALLER_PATH ?= dist/JustSessions.dmg

.PHONY: build dev run check test verify dmg website website-check website-traffic-test website-traffic-deploy website-traffic localization localization-check update-feed-test update-feed-deploy update-checks help

build:
	./Scripts/build-app.sh "$(APP_BUNDLE_PATH)"

dev run: build
	./Scripts/open-dev-app.sh "$(APP_BUNDLE_PATH)"

check:
	swift build

test:
	@runtime_directory="$$(./Scripts/Tmux/build-runtime.sh)" && \
	JUSTSESSIONS_TEST_TMUX_RUNTIME="$$runtime_directory" swift test

# Website deployment checks do not replace local app verification before delivering or tagging.
verify: website-check update-feed-test test localization-check build
	./Scripts/Release/check-app-launches.sh "$(APP_BUNDLE_PATH)"

dmg: build
	./Scripts/build-dmg.sh "$(APP_BUNDLE_PATH)" "$(INSTALLER_PATH)"

website:
	python3 Scripts/Website/build_site.py

website-check: website-traffic-test
	python3 -m unittest discover -s Scripts/Website/tests -v
	node --test Scripts/Website/tests/*.test.mjs
	$(MAKE) website

website-traffic-test:
	node --test Cloudflare/WebsiteTraffic/tests/*.test.js

website-traffic-deploy: website-traffic-test
	cd Cloudflare/WebsiteTraffic && wrangler d1 migrations apply justsessions-website-traffic --remote && wrangler deploy

website-traffic:
	./Cloudflare/WebsiteTraffic/show-website-traffic.sh

localization:
	python3 Scripts/Localization/sync_catalog.py

localization-check:
	python3 Scripts/Localization/sync_catalog.py --check
	python3 -m unittest discover -s Scripts/Localization/tests

update-feed-test:
	node --test Cloudflare/UpdateFeed/tests/*.test.js

update-feed-deploy: update-feed-test
	cd Cloudflare/UpdateFeed && wrangler d1 migrations apply justsessions-update-checks --remote && wrangler deploy

update-checks:
	./Cloudflare/UpdateFeed/show-daily-update-checks.sh

help:
	@printf '%s\n' \
		'make           Build dist/JustSessions.app with bundled tmux' \
		'make dev       Build the app, quit its running copy, and open it' \
		'make run       Alias for make dev' \
		'make check     Compile the Swift development build' \
		'make test      Build bundled tmux and run the Swift tests' \
		'make verify    Check the website, tests, localization, and packaged app launch' \
		'make dmg       Build the app and dist/JustSessions.dmg' \
		'make website   Build and validate the product website' \
		'make website-check  Run the website tests and build' \
		'make website-traffic         Show daily website traffic, sources, countries, and devices' \
		'make website-traffic-test    Test the website traffic Worker' \
		'make website-traffic-deploy  Apply its database migrations and deploy it' \
		'make localization        Extract UI strings and compile translations' \
		'make localization-check  Check UI strings, translations, and resources' \
		'make update-feed-test    Test the Cloudflare Worker that counts update checks' \
		'make update-feed-deploy  Apply its database migrations and deploy it' \
		'make update-checks       Show update checks per day for the last 30 days' \
		'Override output paths with APP_BUNDLE_PATH=... and INSTALLER_PATH=...'
