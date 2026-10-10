import { turnstileAction, turnstileSiteKey } from "./feedback-contract.js";
import { sendWebsiteFeedback } from "./feedback-submission.js";
import { loadTurnstile } from "./turnstile-loader.js";

export const feedbackStatusMessages = {
  sending: "Sending…",
  "sent": "Thanks — your feedback was sent.",
  "invalid-feedback": "Write a message of up to 5,000 characters.",
  "verification-failed": "The spam check didn't pass. Send again once it finishes.",
  "too-many-requests": "That's a lot of messages at once. Wait a minute, then send again.",
  "unavailable": "Feedback couldn't be sent right now. Try again later, or email us.",
  "verification-unavailable": "The spam check couldn't load. Email us instead, or reload the page.",
};

/**
 * Shows the Guide's feedback form, which stays hidden without JavaScript. Cloudflare Turnstile loads only when the
 * visitor first moves into the form, so reading the Guide contacts no one but GitHub. Send waits for its token, and
 * each token is used once.
 */
export function connectFeedbackForm(form, { browser, load = loadTurnstile, send = sendWebsiteFeedback }) {
  const message = form.querySelector('[name="message"]');
  const contact = form.querySelector('[name="contact"]');
  const sendButton = form.querySelector('button[type="submit"]');
  const status = form.querySelector("[data-feedback-status]");
  const verification = form.querySelector("[data-feedback-verification]");
  let turnstile = null;
  let widgetID = null;
  let turnstileToken = null;
  let isSending = false;

  const updateSendButton = () => {
    sendButton.disabled = isSending || !turnstileToken || !message.value.trim();
  };
  const showStatus = (key) => {
    status.textContent = feedbackStatusMessages[key] ?? "";
  };
  const startVerification = async () => {
    form.removeEventListener("focusin", startVerification);
    try {
      turnstile = await load(browser);
    } catch {
      showStatus("verification-unavailable");
      return;
    }
    widgetID = turnstile.render(verification, {
      sitekey: turnstileSiteKey,
      action: turnstileAction,
      cData: "website",
      theme: "light",
      callback: (token) => { turnstileToken = token; updateSendButton(); },
      "expired-callback": () => { turnstileToken = null; updateSendButton(); },
      "error-callback": () => { turnstileToken = null; updateSendButton(); },
    });
  };

  form.addEventListener("focusin", startVerification);
  message.addEventListener("input", updateSendButton);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (sendButton.disabled) return;
    const usedToken = turnstileToken;
    turnstileToken = null;
    isSending = true;
    updateSendButton();
    showStatus("sending");
    const result = await send({ fetch: browser.fetch.bind(browser), message: message.value, contact: contact.value, turnstileToken: usedToken });
    isSending = false;
    if (result === "sent") {
      message.value = "";
      contact.value = "";
    }
    showStatus(result);
    turnstile.reset(widgetID);
    updateSendButton();
  });
  form.hidden = false;
  updateSendButton();
}

if (typeof window !== "undefined") {
  const form = window.document.querySelector("[data-feedback-form]");
  if (form) connectFeedbackForm(form, { browser: window });
}
