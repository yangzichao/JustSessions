import assert from "node:assert/strict";
import { test } from "node:test";
import { startAppVerification } from "../../../website/scripts/feedback/app-verification.js";
import { feedbackEndpoint, turnstileSiteKey } from "../../../website/scripts/feedback/feedback-contract.js";
import { sendWebsiteFeedback } from "../../../website/scripts/feedback/feedback-submission.js";
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

function createGuideForm({ loadFails = false, result = "sent" } = {}) {
  const elements = {
    '[name="message"]': createElement({ value: "" }),
    '[name="contact"]': createElement({ value: "" }),
    'button[type="submit"]': createElement({ disabled: true }),
    "[data-feedback-status]": createElement({ textContent: "" }),
    "[data-feedback-verification]": createElement(),
  };
  const form = createElement({ hidden: true, querySelector: (selector) => elements[selector] });
  const turnstile = createTurnstile();
  const loads = [];
  const sends = [];
  connectFeedbackForm(form, {
    browser: { fetch() {} },
    load: async () => { loads.push(true); if (loadFails) throw new Error("Blocked"); return turnstile; },
    send: async (submission) => { sends.push(submission); return result; },
  });
  return {
    form, turnstile, loads, sends,
    message: elements['[name="message"]'], contact: elements['[name="contact"]'],
    sendButton: elements['button[type="submit"]'], status: elements["[data-feedback-status]"],
    solveVerification(token) { turnstile.renders.at(-1).options.callback(token); },
    submit: () => form.dispatch("submit", { preventDefault() {} }),
  };
}

test("the Guide posts feedback as JSON from the website, without credentials, a referrer, or a blank contact", async () => {
  const requests = [];
  const fetch = async (address, options) => { requests.push({ address, options }); return { json: async () => ({ result: "sent" }) }; };
  assert.equal(await sendWebsiteFeedback({ fetch, message: "Hi", contact: "  ", turnstileToken: "token" }), "sent");
  assert.equal(requests[0].address, feedbackEndpoint);
  assert.equal(requests[0].options.credentials, "omit");
  assert.equal(requests[0].options.referrerPolicy, "no-referrer");
  assert.deepEqual(JSON.parse(requests[0].options.body), { message: "Hi", source: "website", turnstileToken: "token" });
});

test("a refusal keeps its reason; anything unexpected or unreachable reads as unavailable", async () => {
  const answering = (body) => async () => ({ json: async () => body });
  assert.equal(await sendWebsiteFeedback({ fetch: answering({ result: "too-many-requests" }), message: "Hi", contact: "", turnstileToken: "t" }), "too-many-requests");
  assert.equal(await sendWebsiteFeedback({ fetch: answering({ result: "<script>" }), message: "Hi", contact: "", turnstileToken: "t" }), "unavailable");
  assert.equal(await sendWebsiteFeedback({ fetch: async () => { throw new Error("Offline"); }, message: "Hi", contact: "", turnstileToken: "t" }), "unavailable");
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
  assert.deepEqual(guide.sends.map(({ message, contact, turnstileToken }) => [message, contact, turnstileToken]), [["Love it", "me@example.com", "token-1"]]);
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

function createAppPage({ address = "https://yangzichao.github.io/JustSessions/app-feedback-verification.html?theme=dark&language=zh-Hans", inApp = true } = {}) {
  const messages = [];
  const container = {};
  const page = {
    location: { href: address },
    document: { getElementById: (id) => (id === "verification" ? container : null) },
    ...(inApp ? { webkit: { messageHandlers: { turnstile: { postMessage: (message) => messages.push(message) } } } } : {}),
  };
  return { page, messages, container };
}

test("in the app, the check matches the app's appearance and language and reports each token to it", async () => {
  const { page, messages, container } = createAppPage();
  const turnstile = createTurnstile();
  assert.equal(await startAppVerification(page, async () => turnstile), true);
  const { container: renderedInto, options } = turnstile.renders[0];
  assert.equal(renderedInto, container);
  assert.deepEqual([options.cData, options.action, options.theme, options.language], ["app", "feedback", "dark", "zh-cn"]);
  options.callback("token-1");
  options["expired-callback"]();
  options["error-callback"]();
  assert.deepEqual(messages, [{ event: "verified", token: "token-1" }, { event: "expired" }, { event: "error" }]);
  page.resetVerification();
  assert.deepEqual(turnstile.resets, ["widget-1"]);
});

test("unknown app settings fall back to Turnstile's own, and a blocked script reports an error", async () => {
  const known = createAppPage({ address: "https://yangzichao.github.io/JustSessions/app-feedback-verification.html?theme=sepia&language=fr" });
  const turnstile = createTurnstile();
  await startAppVerification(known.page, async () => turnstile);
  assert.deepEqual([turnstile.renders[0].options.theme, turnstile.renders[0].options.language], ["light", "auto"]);

  const blocked = createAppPage();
  assert.equal(await startAppVerification(blocked.page, async () => { throw new Error("Blocked"); }), false);
  assert.deepEqual(blocked.messages, [{ event: "error" }]);
});

test("opened outside the app, the check page loads nothing", async () => {
  let loaded = false;
  assert.equal(await startAppVerification(createAppPage({ inApp: false }).page, async () => { loaded = true; }), false);
  assert.equal(loaded, false);
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
