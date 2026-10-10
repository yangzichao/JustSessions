import assert from "node:assert/strict";
import { test } from "node:test";
import { readAppVersions } from "../../../website/scripts/feedback/app-versions.js";
import { feedbackEndpoint, turnstileSiteKey } from "../../../website/scripts/feedback/feedback-contract.js";
import { sendFeedback } from "../../../website/scripts/feedback/feedback-submission.js";
import { connectFeedbackForm, feedbackStatusMessages } from "../../../website/scripts/feedback/guide-feedback-form.js";
import { loadTurnstile } from "../../../website/scripts/feedback/turnstile-loader.js";

function createElement(properties = {}) {
  const listeners = new Map();
  return {
    ...properties,
    addEventListener(type, listener) { listeners.set(type, [...(listeners.get(type) ?? []), listener]); },
    removeEventListener(type, listener) { listeners.set(type, (listeners.get(type) ?? []).filter((existing) => existing !== listener)); },
    async dispatch(type, event = {}) { for (const listener of listeners.get(type) ?? []) await listener(event); },
  };
}

function createTurnstile() {
  const turnstile = { renders: [], resets: [] };
  turnstile.render = (container, options) => { turnstile.renders.push({ container, options }); return "widget-1"; };
  turnstile.reset = (widgetID) => turnstile.resets.push(widgetID);
  return turnstile;
}

function createGuideForm({ loadFails = false, result = "sent", search = "" } = {}) {
  const elements = {
    '[name="message"]': createElement({ value: "" }),
    '[name="contact"]': createElement({ value: "" }),
    'button[type="submit"]': createElement({ disabled: true }),
    "[data-feedback-status]": createElement({ textContent: "" }),
    "[data-feedback-verification]": createElement(),
    "[data-feedback-app-versions]": createElement({ hidden: true, textContent: "" }),
  };
  const form = createElement({ hidden: true, querySelector: (selector) => elements[selector] });
  const turnstile = createTurnstile();
  const loads = [];
  const sends = [];
  connectFeedbackForm(form, {
    browser: { fetch() {}, location: { search } },
    load: async () => { loads.push(true); if (loadFails) throw new Error("Blocked"); return turnstile; },
    send: async (submission) => { sends.push(submission); return result; },
  });
  return {
    form, turnstile, loads, sends,
    message: elements['[name="message"]'], contact: elements['[name="contact"]'],
    sendButton: elements['button[type="submit"]'], status: elements["[data-feedback-status]"],
    appVersionsLine: elements["[data-feedback-app-versions]"],
    solveVerification(token) { turnstile.renders.at(-1).options.callback(token); },
    submit: () => form.dispatch("submit", { preventDefault() {} }),
  };
}

test("the Guide posts feedback as JSON from the website, without credentials, a referrer, or a blank contact", async () => {
  const requests = [];
  const fetch = async (address, options) => { requests.push({ address, options }); return { json: async () => ({ result: "sent" }) }; };
  assert.equal(await sendFeedback({ fetch, message: "Hi", contact: "  ", source: "website", appVersions: null, turnstileToken: "token" }), "sent");
  assert.equal(requests[0].address, feedbackEndpoint);
  assert.equal(requests[0].options.credentials, "omit");
  assert.equal(requests[0].options.referrerPolicy, "no-referrer");
  assert.deepEqual(JSON.parse(requests[0].options.body), { message: "Hi", source: "website", turnstileToken: "token" });

  const appVersions = { appVersion: "1.1.0 (98)", macOSVersion: "26.5" };
  await sendFeedback({ fetch, message: "Hi", contact: "", source: "app", appVersions, turnstileToken: "token" });
  assert.deepEqual(JSON.parse(requests[1].options.body), { message: "Hi", source: "app", ...appVersions, turnstileToken: "token" });
});

test("a refusal keeps its reason; anything unexpected or unreachable reads as unavailable", async () => {
  const answering = (body) => async () => ({ json: async () => body });
  const submission = { message: "Hi", contact: "", source: "website", appVersions: null, turnstileToken: "t" };
  assert.equal(await sendFeedback({ ...submission, fetch: answering({ result: "too-many-requests" }) }), "too-many-requests");
  assert.equal(await sendFeedback({ ...submission, fetch: answering({ result: "<script>" }) }), "unavailable");
  assert.equal(await sendFeedback({ ...submission, fetch: async () => { throw new Error("Offline"); } }), "unavailable");
});

test("the form appears with JavaScript, but Turnstile loads only once the visitor moves into it", async () => {
  const guide = createGuideForm();
  assert.equal(guide.form.hidden, false);
  assert.equal(guide.loads.length, 0);
  await guide.form.dispatch("focusin");
  await guide.form.dispatch("focusin");
  assert.equal(guide.loads.length, 1);
  assert.equal(guide.turnstile.renders[0].options.sitekey, turnstileSiteKey);
  assert.equal(guide.turnstile.renders[0].options.action, "feedback");
  assert.equal(guide.turnstile.renders[0].options.cData, "website");
  assert.equal(guide.appVersionsLine.hidden, true);
});

test("Send waits for both a message and a solved check, and each token is sent once", async () => {
  const guide = createGuideForm();
  await guide.form.dispatch("focusin");
  guide.message.value = "Love it";
  await guide.message.dispatch("input");
  assert.equal(guide.sendButton.disabled, true);
  guide.solveVerification("token-1");
  assert.equal(guide.sendButton.disabled, false);

  guide.contact.value = "me@example.com";
  await guide.submit();
  assert.deepEqual(
    guide.sends.map(({ message, contact, source, appVersions, turnstileToken }) => [message, contact, source, appVersions, turnstileToken]),
    [["Love it", "me@example.com", "website", null, "token-1"]],
  );
  assert.equal(guide.status.textContent, feedbackStatusMessages.sent);
  assert.equal(guide.message.value, "");
  assert.equal(guide.contact.value, "");
  assert.deepEqual(guide.turnstile.resets, ["widget-1"]);
  assert.equal(guide.sendButton.disabled, true);
  await guide.submit();
  assert.equal(guide.sends.length, 1);
});

test("a refused message stays in the form to send again", async () => {
  const guide = createGuideForm({ result: "verification-failed" });
  await guide.form.dispatch("focusin");
  guide.message.value = "Love it";
  guide.solveVerification("token-1");
  await guide.submit();
  assert.equal(guide.message.value, "Love it");
  assert.equal(guide.status.textContent, feedbackStatusMessages["verification-failed"]);
  guide.solveVerification("token-2");
  assert.equal(guide.sendButton.disabled, false);
});

test("a blocked Turnstile says so and leaves the email link as the way to write", async () => {
  const guide = createGuideForm({ loadFails: true });
  await guide.form.dispatch("focusin");
  assert.equal(guide.status.textContent, feedbackStatusMessages["verification-unavailable"]);
  assert.equal(guide.sendButton.disabled, true);
});

test("opened by the app, the form shows its versions and sends as the app", async () => {
  const guide = createGuideForm({ search: "?appVersion=1.1.0%20(98)&macOSVersion=26.5" });
  assert.equal(guide.appVersionsLine.hidden, false);
  assert.equal(guide.appVersionsLine.textContent, "Sent with JustSessions 1.1.0 (98) on macOS 26.5.");
  assert.equal(guide.loads.length, 0);
  await guide.form.dispatch("focusin");
  assert.equal(guide.turnstile.renders[0].options.cData, "app");
  guide.message.value = "Search is slow";
  guide.solveVerification("token-1");
  await guide.submit();
  assert.deepEqual(guide.sends.map(({ source, appVersions }) => [source, appVersions]), [["app", { appVersion: "1.1.0 (98)", macOSVersion: "26.5" }]]);
});

test("versions the Worker would refuse, or only one of them, leave the form as the website's", () => {
  assert.deepEqual(readAppVersions("?appVersion=1.1.0-3-gf45492c%20(0)&macOSVersion=26.5.1"), { appVersion: "1.1.0-3-gf45492c (0)", macOSVersion: "26.5.1" });
  for (const search of ["", "?appVersion=1.1.0", "?appVersion=%3Cb%3E&macOSVersion=26.5", `?appVersion=${"1".repeat(41)}&macOSVersion=26.5`]) {
    assert.equal(readAppVersions(search), null, search);
  }
  const guide = createGuideForm({ search: "?appVersion=1.1.0%20(98)" });
  assert.equal(guide.appVersionsLine.hidden, true);
});

test("Turnstile's script is added once from Cloudflare, and a failed load can be tried again", async () => {
  const scripts = [];
  const browser = { document: {
    createElement: () => ({ remove() { scripts.splice(scripts.indexOf(this), 1); } }),
    head: { append: (script) => scripts.push(script) },
  } };
  const failedLoad = loadTurnstile(browser);
  scripts[0].onerror();
  await assert.rejects(failedLoad, /could not load/);
  assert.equal(scripts.length, 0);

  const firstLoad = loadTurnstile(browser);
  const secondLoad = loadTurnstile(browser);
  assert.equal(scripts.length, 1);
  assert.equal(scripts[0].src, "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=justSessionsTurnstileLoaded");
  browser.turnstile = createTurnstile();
  browser.justSessionsTurnstileLoaded();
  assert.equal(await firstLoad, browser.turnstile);
  assert.equal(await secondLoad, browser.turnstile);
});
