import assert from "node:assert/strict";
import { test } from "node:test";
import worker from "../src/worker.js";
import { classifyDevice, countryCategory } from "../src/traffic-dimensions.js";

function createHarness({ address = "https://traffic.example/pageview?page=home&source=github", method = "POST", origin = "https://yangzichao.github.io", headers = {}, country = "US", fails = false } = {}) {
  const writes = [];
  const request = new Request(address, { method, headers: { Origin: origin, "User-Agent": "Mozilla/5.0 Chrome/140.0", ...headers } });
  Object.defineProperty(request, "cf", { value: { country } });
  const env = { WEBSITE_TRAFFIC_DATABASE: {
    prepare(sql) { return {
      bind(...values) { writes.push({ sql, values }); return this; },
      async run() { if (fails) throw new Error("Database unavailable"); return { success: true }; },
    }; },
  } };
  return { request, env, writes };
}

test("a page view writes only the UTC day and bounded aggregate dimensions", async () => {
  const harness = createHarness();
  const response = await worker.fetch(harness.request, harness.env);
  assert.equal(response.status, 204);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "https://yangzichao.github.io");
  assert.equal(response.headers.get("Access-Control-Allow-Credentials"), null);
  assert.equal(response.headers.get("Set-Cookie"), null);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(harness.writes.length, 1);
  assert.match(harness.writes[0].values[0], /^\d{4}-\d{2}-\d{2}$/);
  assert.deepEqual(harness.writes[0].values.slice(1), ["home", "github", "US", "desktop"]);
});

test("wrong origin, missing origin, wrong route, and GET never count", async () => {
  for (const [options, status] of [[{ origin: "https://unrelated.example" }, 403], [{ origin: "null" }, 403], [{ address: "https://traffic.example/stats" }, 404], [{ method: "GET" }, 405]]) {
    const harness = createHarness(options);
    assert.equal((await worker.fetch(harness.request, harness.env)).status, status);
    assert.equal(harness.writes.length, 0);
  }
});

test("preflight allows only the published origin and never counts", async () => {
  const harness = createHarness({ method: "OPTIONS" });
  const response = await worker.fetch(harness.request, harness.env);
  assert.equal(response.status, 204);
  assert.equal(response.headers.get("Access-Control-Allow-Methods"), "POST");
  assert.equal(harness.writes.length, 0);
});

test("unbounded source values, unknown pages, extra fields, and duplicate parameters are rejected", async () => {
  for (const query of ["page=home&source=private.example", "page=unknown&source=direct", "page=home&source=direct&email=private", "page=home&page=guide&source=direct", "page=home&source=direct&source=github"]) {
    const harness = createHarness({ address: `https://traffic.example/pageview?${query}` });
    assert.equal((await worker.fetch(harness.request, harness.env)).status, 400);
    assert.equal(harness.writes.length, 0);
  }
});

test("known bots and privacy opt-outs do not count", async () => {
  for (const headers of [{ "User-Agent": "Googlebot" }, { "User-Agent": "curl/8.0" }, { "User-Agent": "" }, { "Sec-GPC": "1" }, { DNT: "1" }]) {
    const harness = createHarness({ headers });
    assert.equal((await worker.fetch(harness.request, harness.env)).status, 204);
    assert.equal(harness.writes.length, 0);
  }
});

test("a failed database write reports failure without request data", async () => {
  const harness = createHarness({ fails: true });
  assert.equal((await worker.fetch(harness.request, harness.env)).status, 503);
});

test("country and device values are coarse categories", () => {
  assert.equal(countryCategory("DE"), "DE");
  for (const value of [null, "XX", "private-country", "US; DROP TABLE traffic"]) assert.equal(countryCategory(value), "unknown");
  assert.equal(classifyDevice("Mozilla iPhone Mobile"), "mobile");
  assert.equal(classifyDevice("Mozilla Android 14 Tablet"), "tablet");
  assert.equal(classifyDevice("Mozilla iPad"), "tablet");
  assert.equal(classifyDevice("Mozilla Mac OS X"), "desktop");
});

test("scheduled retention waits for its database operation and propagates failures", async () => {
  let completed = false;
  const database = { prepare(sql) {
    assert.match(sql, /DELETE FROM daily_website_traffic WHERE utc_day < date\('now', '-180 days'\)/);
    return { async run() { await Promise.resolve(); completed = true; } };
  } };
  await worker.scheduled({}, { WEBSITE_TRAFFIC_DATABASE: database });
  assert.equal(completed, true);
  database.prepare = () => ({ async run() { throw new Error("Database unavailable"); } });
  await assert.rejects(worker.scheduled({}, { WEBSITE_TRAFFIC_DATABASE: database }), /Database unavailable/);
});
