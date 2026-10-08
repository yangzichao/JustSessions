import assert from "node:assert/strict";
import { test } from "node:test";
import { recordWebsitePageView } from "../../../website/scripts/traffic/traffic-monitor.js";
import { classifyTrafficSource } from "../../../website/scripts/traffic/traffic-categories.js";

function createBrowser(address = "https://yangzichao.github.io/JustSessions/?secret=private#terminal") {
  const requests = [];
  return {
    location: new URL(address), navigator: {}, document: { referrer: "https://github.com/private/repo?token=secret" }, requests,
    async fetch(address, options) { requests.push({ address, options }); return { ok: true }; },
  };
}

test("a production page reports only fixed categories, with no credentials or referrer", async () => {
  const browser = createBrowser();
  assert.equal(await recordWebsitePageView(browser), true);
  assert.equal(browser.requests.length, 1);
  const request = browser.requests[0];
  assert.equal(new URL(request.address).search, "?page=home&source=github");
  assert.deepEqual(request.options, { method: "POST", credentials: "omit", referrerPolicy: "no-referrer", keepalive: true });
  assert.doesNotMatch(request.address, /private|secret|token/);
});

test("local previews, unrelated GitHub projects, errors, and redirect pages never report", async () => {
  for (const address of ["http://127.0.0.1:8765/JustSessions/", "https://yangzichao.github.io/Other/", "https://yangzichao.github.io/JustSessions/404.html", "https://yangzichao.github.io/JustSessions/help.html"]) {
    const browser = createBrowser(address);
    assert.equal(await recordWebsitePageView(browser), false);
    assert.equal(browser.requests.length, 0);
  }
});

test("the homepage aliases and Guide use stable page names", async () => {
  for (const [path, page] of [["/JustSessions", "home"], ["/JustSessions/index.html", "home"], ["/JustSessions/guide.html", "guide"]]) {
    const browser = createBrowser(`https://yangzichao.github.io${path}`);
    await recordWebsitePageView(browser);
    assert.equal(new URL(browser.requests[0].address).searchParams.get("page"), page);
  }
});

test("browser privacy preferences and automated checks send no request", async () => {
  for (const preferences of [{ globalPrivacyControl: true }, { doNotTrack: "1" }, { webdriver: true }]) {
    const browser = createBrowser();
    Object.assign(browser.navigator, preferences);
    assert.equal(await recordWebsitePageView(browser), false);
    assert.equal(browser.requests.length, 0);
  }
});

test("blocked or unavailable analytics never retries or interrupts the page", async () => {
  const browser = createBrowser();
  let attempts = 0;
  browser.fetch = async () => { attempts++; throw new Error("Blocked"); };
  assert.equal(await recordWebsitePageView(browser), false);
  assert.equal(attempts, 1);
});

test("referral categories discard arbitrary domains, paths, and query strings", () => {
  assert.equal(classifyTrafficSource(""), "direct");
  assert.equal(classifyTrafficSource("https://yangzichao.github.io/JustSessions/?private=yes"), "internal");
  assert.equal(classifyTrafficSource("https://www.google.co.uk/search?q=private"), "google");
  assert.equal(classifyTrafficSource("https://news.ycombinator.com/item?id=123"), "hacker-news");
  assert.equal(classifyTrafficSource("https://github.com.attacker.example/private"), "other");
  assert.equal(classifyTrafficSource("https://private.example/?secret=yes"), "other");
  assert.equal(classifyTrafficSource("invalid URL"), "other");
});
