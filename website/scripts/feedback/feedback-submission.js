import { feedbackEndpoint } from "./feedback-contract.js";

const workerResults = new Set(["sent", "invalid-feedback", "verification-failed", "too-many-requests", "unavailable"]);

/**
 * Sends the Guide's feedback to the Worker, with the app's versions when the app opened the form: "sent", one of the
 * Worker's refusals, or "unavailable" when it could not be reached or answered something else.
 */
export async function sendFeedback({ fetch, message, contact, source, appVersions, turnstileToken }) {
  try {
    const response = await fetch(feedbackEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message, ...(contact.trim() ? { contact } : {}), source, ...appVersions, turnstileToken }),
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    const { result } = await response.json();
    return workerResults.has(result) ? result : "unavailable";
  } catch {
    return "unavailable";
  }
}
