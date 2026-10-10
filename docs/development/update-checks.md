# Counting update checks

[Back to JustSessions](../../README.md) · [Build and release](build-and-release.md)

JustSessions has no analytics and sends no identifiers. To estimate how many installs are in use, a Cloudflare Worker counts Sparkle's update checks per day.

## What is counted

Sparkle checks the update feed automatically at most once a day per install (Sparkle 2's default interval, which the app does not change). The number of checks on a UTC day is therefore close to the number of installs that ran that day.

The app's `SUFeedURL` is `https://justsessions-update-feed.noether-lab.workers.dev/appcast.xml`, served by the `justsessions-update-feed` Worker in `Cloudflare/UpdateFeed/` on zichao.yang.phys@gmail.com's Cloudflare account. For each `GET /appcast.xml` whose user agent is exactly Sparkle's `JustSessions/<version> Sparkle/<version>`, it adds 1 to a D1 row keyed by UTC day and app version, then redirects to `https://github.com/yangzichao/JustSessions/releases/latest/download/appcast.xml`. Other clients are redirected without being counted. If the count cannot be saved, the redirect still happens.

The `justsessions-update-checks` database holds only `utc_day`, `app_version`, and `check_count`. The Worker stores no IP address, user agent, or other request data, and persisted Workers logs are turned off. Cloudflare and GitHub still serve the requests under their own policies.

Read the numbers with these limits in mind:

- They count installs, not people. Someone with two Macs counts twice.
- A manual **Check for Updates** also counts. Local development builds don't check automatically, and their versions, such as `1.1.0-3-gf45492c`, aren't counted; see [Build from source](build-and-release.md#build-from-source).
- Installs with automatic checks turned off, or without network access, are not counted.
- Installs from before the Worker became the feed still fetch GitHub's appcast directly until they update.

## Commands

Run these from the repository root. They use the Cloudflare account `wrangler login` signed in to, and `account_id` in `wrangler.jsonc` makes them fail on any other account.

```sh
make update-checks       # Update checks per UTC day for the last 30 days, split by app version
make update-feed-test    # Worker tests; also part of make verify
make update-feed-deploy  # Run the tests, apply D1 migrations, and deploy the Worker
wrangler tail --config Cloudflare/UpdateFeed/wrangler.jsonc  # Watch live errors
```

`./Cloudflare/UpdateFeed/show-daily-update-checks.sh 90` shows a different number of days.

## Keeping the feed working

Every released app keeps fetching the `SUFeedURL` it shipped with, so the Worker must stay deployed at that address. If it goes down, installed apps stop finding updates until it is back. To move the feed, release a version with the new `SUFeedURL` and keep the old address redirecting until older installs have updated.

A schema change goes in a new numbered file in `Cloudflare/UpdateFeed/migrations/`; `make update-feed-deploy` applies it before deploying.
