import { feedbackEndpoint } from "./feedback-contract.js";

const workerResults = new Set(["sent", "invalid-feedback", "verification-failed", "too-many-requests", "unavailable"]);

/**
 * Sends the Guide's feedback to the Worker: "sent", one of the Worker's refusals, or "unavailable" when it could not
 * be reached or answered something else.
 */
export async function sendWebsiteFeedback({ fetch, message, contact, turnstileToken }) {
  try {
    const response = await fetch(feedbackEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message, ...(contact.trim() ? { contact } : {}), source: "website", turnstileToken }),
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
    const { result } = await response.json();
    return workerResults.has(result) ? result : "unavailable";
  } catch {
    return "unavailable";
  }
}
