import assert from "node:assert/strict";
import { test } from "node:test";

import worker, { githubAppcastURL } from "../src/worker.js";

const sparkleUserAgent = "JustSessions/0.36.1 Sparkle/2.10.0";

/** Records the statements the Worker runs instead of talking to D1. */
function makeRecordingDatabase({ failsOnRun = false } = {}) {
    const boundValues = [];
    return {
        boundValues,
        prepare(statement) {
            return {
                bind(...values) {
                    return {
                        async run() {
                            if (failsOnRun) throw new Error("D1 is unavailable");
                            boundValues.push({ statement, values });
                        },
                    };
                },
            };
        },
    };
}

/** Collects background work so the test can wait for it like the Workers runtime does. */
function makeExecutionContext() {
    const backgroundWork = [];
    return {
        backgroundWork,
        waitUntil(promise) {
            backgroundWork.push(promise);
        },
    };
}

async function requestFeed({ path = "/appcast.xml", method = "GET", userAgent = sparkleUserAgent, database } = {}) {
    const headers = userAgent === null ? {} : { "User-Agent": userAgent };
    const request = new Request(`https://justsessions-update-feed.example.workers.dev${path}`, { method, headers });
    const ctx = makeExecutionContext();
    const response = await worker.fetch(request, { UPDATE_CHECKS_DATABASE: database }, ctx);
    await Promise.all(ctx.backgroundWork);
    return response;
}

test("sends Sparkle on to the newest appcast on GitHub without caching the redirect", async () => {
    const response = await requestFeed({ database: makeRecordingDatabase() });

    assert.equal(response.status, 302);
    assert.equal(response.headers.get("Location"), githubAppcastURL);
    assert.equal(response.headers.get("Cache-Control"), "no-store");
});

test("counts a Sparkle check under today's UTC day and its app version", async () => {
    const database = makeRecordingDatabase();
    await requestFeed({ database });

    assert.equal(database.boundValues.length, 1);
    const [utcDay, appVersion] = database.boundValues[0].values;
    assert.match(utcDay, /^\d{4}-\d{2}-\d{2}$/);
    assert.equal(appVersion, "0.36.1");
    assert.match(database.boundValues[0].statement, /ON CONFLICT \(utc_day, app_version\) DO UPDATE/);
});

test("redirects other clients without counting them", async () => {
    for (const userAgent of [null, "Mozilla/5.0", "curl/8.7.1"]) {
        const database = makeRecordingDatabase();
        const response = await requestFeed({ userAgent, database });

        assert.equal(response.status, 302, String(userAgent));
        assert.equal(database.boundValues.length, 0, String(userAgent));
    }
});

test("does not count HEAD requests", async () => {
    const database = makeRecordingDatabase();
    const response = await requestFeed({ method: "HEAD", database });

    assert.equal(response.status, 302);
    assert.equal(database.boundValues.length, 0);
});

test("still redirects when the count cannot be saved", async (testContext) => {
    testContext.mock.method(console, "error", () => {});
    const response = await requestFeed({ database: makeRecordingDatabase({ failsOnRun: true }) });

    assert.equal(response.status, 302);
    assert.equal(console.error.mock.callCount(), 1);
});

test("answers only the appcast path and read methods", async () => {
    const database = makeRecordingDatabase();

    assert.equal((await requestFeed({ path: "/", database })).status, 404);
    assert.equal((await requestFeed({ path: "/appcast.xml.bak", database })).status, 404);
    const postResponse = await requestFeed({ method: "POST", database });
    assert.equal(postResponse.status, 405);
    assert.equal(postResponse.headers.get("Allow"), "GET, HEAD");
    assert.equal(database.boundValues.length, 0);
});
