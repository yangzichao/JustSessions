import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import worker from "../src/worker.js";
import { siteverifyURL } from "../src/turnstile-verification.js";

const websiteFeedback = { message: "  Love the tabs.  ", contact: "me@example.com", source: "website", turnstileToken: "token-1" };
const appFeedback = { message: "Search is slow", source: "app", appVersion: "1.0.13 (32)", macOSVersion: "26.0.1", turnstileToken: "token-2" };
const verifiedOutcome = (source) => ({ success: true, hostname: "yangzichao.github.io", action: "feedback", cdata: source });
const originalFetch = globalThis.fetch;

afterEach(() => { globalThis.fetch = originalFetch; });

function createHarness({
  body = websiteFeedback, bodyText = JSON.stringify(body), method = "POST", address = "https://feedback.example/feedback",
  origin = "https://yangzichao.github.io", headers = {}, withinRateLimit = true, secret = "secret",
  siteverify = async () => Response.json(verifiedOutcome(body.source)), storageFails = false,
} = {}) {
  const writes = [];
  const siteverifyRequests = [];
  const rateLimitKeys = [];
  const requestHeaders = { "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.7", ...(origin ? { Origin: origin } : {}), ...headers };
  const request = new Request(address, { method, headers: requestHeaders, ...(method === "POST" ? { body: bodyText } : {}) });
  globalThis.fetch = async (url, options) => {
    assert.equal(url, siteverifyURL);
    siteverifyRequests.push(JSON.parse(options.body));
    return siteverify();
  };
  const env = {
    TURNSTILE_SECRET_KEY: secret,
    FEEDBACK_RATE_LIMITER: { async limit({ key }) { rateLimitKeys.push(key); return { success: withinRateLimit }; } },
    FEEDBACK_DATABASE: { prepare(sql) { return {
      bind(...values) { writes.push({ sql, values }); return this; },
      async run() { if (storageFails) throw new Error("Database unavailable"); return { success: true }; },
    }; } },
  };
  return { request, env, writes, siteverifyRequests, rateLimitKeys };
}

async function send(harness) {
  const response = await worker.fetch(harness.request, harness.env);
  const text = await response.text();
  return { response, result: text ? JSON.parse(text).result : undefined };
}

test("website feedback is verified, then stored trimmed without its token or the sender's address", async () => {
  const harness = createHarness();
  const { response, result } = await send(harness);
  assert.equal(response.status, 201);
  assert.equal(result, "sent");
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "https://yangzichao.github.io");
  assert.equal(response.headers.get("Set-Cookie"), null);
  assert.deepEqual(harness.siteverifyRequests, [{ secret: "secret", response: "token-1", remoteip: "203.0.113.7" }]);
  assert.deepEqual(harness.rateLimitKeys, ["203.0.113.7"]);
  assert.equal(harness.writes.length, 1);
  assert.deepEqual(harness.writes[0].values, ["website", "Love the tabs.", "me@example.com", null, null]);
  assert.doesNotMatch(harness.writes[0].sql, /ip|agent|token/i);
});

test("app feedback, which has no Origin, keeps its versions", async () => {
  const harness = createHarness({ body: appFeedback, origin: null });
  assert.equal((await send(harness)).response.status, 201);
  assert.deepEqual(harness.writes[0].values, ["app", "Search is slow", null, "1.0.13 (32)", "26.0.1"]);
});

test("other sites, other routes, and other methods are refused before anything is checked", async () => {
  for (const [options, status] of [
    [{ origin: "https://unrelated.example" }, 403], [{ origin: "null" }, 403],
    [{ address: "https://feedback.example/stats" }, 404], [{ method: "GET" }, 405],
  ]) {
    const harness = createHarness(options);
    assert.equal((await send(harness)).response.status, status);
    assert.equal(harness.siteverifyRequests.length + harness.rateLimitKeys.length + harness.writes.length, 0);
  }
});

test("the preflight allows a JSON POST from the website only", async () => {
  const harness = createHarness({ method: "OPTIONS" });
  const { response } = await send(harness);
  assert.equal(response.status, 204);
  assert.equal(response.headers.get("Access-Control-Allow-Methods"), "POST");
  assert.equal(response.headers.get("Access-Control-Allow-Headers"), "Content-Type");
  assert.equal(harness.writes.length, 0);
});

test("bodies that are not small JSON are refused", async () => {
  for (const [options, status] of [
    [{ headers: { "Content-Type": "text/plain" } }, 415],
    [{ headers: { "Content-Type": "application/x-www-form-urlencoded" } }, 415],
    [{ bodyText: JSON.stringify({ ...websiteFeedback, message: "x".repeat(70_000) }) }, 413],
    [{ bodyText: "{not json" }, 400],
  ]) {
    const harness = createHarness(options);
    assert.equal((await send(harness)).response.status, status);
    assert.equal(harness.writes.length, 0);
  }
});

test("feedback that is empty, too long, or not shaped like the website's or app's is refused unverified", async () => {
  for (const body of [
    { ...websiteFeedback, message: "   " },
    { ...websiteFeedback, message: "x".repeat(5001) },
    { ...websiteFeedback, contact: "x".repeat(201) },
    { ...websiteFeedback, contact: 42 },
    { ...websiteFeedback, name: "extra field" },
    { ...websiteFeedback, source: "email" },
    { ...websiteFeedback, appVersion: "1.0.13" },
    { ...appFeedback, macOSVersion: undefined },
    { ...appFeedback, appVersion: "1.0.13; DROP TABLE feedback" },
    { ...appFeedback, appVersion: "1".repeat(41) },
    { ...websiteFeedback, turnstileToken: "" },
    { ...websiteFeedback, turnstileToken: "x".repeat(2049) },
    ["Love the tabs."],
  ]) {
    const harness = createHarness({ body });
    const { response, result } = await send(harness);
    assert.equal(response.status, 400, JSON.stringify(body).slice(0, 80));
    assert.equal(result, "invalid-feedback");
    assert.equal(harness.siteverifyRequests.length, 0);
    assert.equal(harness.writes.length, 0);
  }
});

test("a sender over the rate limit is refused before Turnstile is asked", async () => {
  const harness = createHarness({ withinRateLimit: false });
  const { response, result } = await send(harness);
  assert.equal(response.status, 429);
  assert.equal(result, "too-many-requests");
  assert.equal(harness.siteverifyRequests.length, 0);
});

test("a token Turnstile rejects, or one solved elsewhere, for another action, or for the other source, stores nothing", async () => {
  for (const outcome of [
    { success: false, "error-codes": ["timeout-or-duplicate"] },
    { ...verifiedOutcome("website"), hostname: "localhost" },
    { ...verifiedOutcome("website"), action: "login" },
    verifiedOutcome("app"),
  ]) {
    const harness = createHarness({ siteverify: async () => Response.json(outcome) });
    const { response, result } = await send(harness);
    assert.equal(response.status, 403);
    assert.equal(result, "verification-failed");
    assert.equal(harness.writes.length, 0);
  }
});

test("a missing or wrong secret, or an unreachable Turnstile, reports the service unavailable", async () => {
  for (const options of [
    { secret: "" },
    { siteverify: async () => Response.json({ success: false, "error-codes": ["invalid-input-secret"] }) },
    { siteverify: async () => new Response("Bad gateway", { status: 502 }) },
    { siteverify: async () => { throw new Error("Network down"); } },
  ]) {
    const harness = createHarness(options);
    const { response, result } = await send(harness);
    assert.equal(response.status, 503);
    assert.equal(result, "unavailable");
    assert.equal(harness.writes.length, 0);
  }
});

test("a failed database write reports the service unavailable", async () => {
  const { response, result } = await send(createHarness({ storageFails: true }));
  assert.equal(response.status, 503);
  assert.equal(result, "unavailable");
});

test("scheduled retention deletes feedback older than a year and propagates failures", async () => {
  let completed = false;
  const database = { prepare(sql) {
    assert.match(sql, /DELETE FROM feedback WHERE received_at < strftime\('%Y-%m-%dT%H:%M:%SZ', 'now', '-365 days'\)/);
    return { async run() { await Promise.resolve(); completed = true; } };
  } };
  await worker.scheduled({}, { FEEDBACK_DATABASE: database });
  assert.equal(completed, true);
  database.prepare = () => ({ async run() { throw new Error("Database unavailable"); } });
  await assert.rejects(worker.scheduled({}, { FEEDBACK_DATABASE: database }), /Database unavailable/);
});
