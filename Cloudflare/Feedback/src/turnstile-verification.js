import { turnstileAction, turnstileHostname } from "../../../website/scripts/feedback/feedback-contract.js";

export const siteverifyURL = "https://challenges.cloudflare.com/turnstile/v0/siteverify";
// Siteverify reports these when the Worker's own secret is wrong, not the visitor's token.
const secretErrorCodes = new Set(["missing-input-secret", "invalid-input-secret"]);

/**
 * Whether Cloudflare accepts `token` as solved on the published website for feedback from `source`:
 * "verified", "rejected" for a bad, reused, or expired token, or "unavailable" when it cannot be checked.
 * Each token can be checked once.
 */
export async function verifyTurnstileToken({ token, source, secret, remoteIP, fetch = globalThis.fetch }) {
  if (!secret) {
    console.error("TURNSTILE_SECRET_KEY is not set");
    return "unavailable";
  }
  let outcome;
  try {
    const response = await fetch(siteverifyURL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ secret, response: token, ...(remoteIP ? { remoteip: remoteIP } : {}) }),
    });
    if (!response.ok) {
      console.error(`Turnstile siteverify answered HTTP ${response.status}`);
      return "unavailable";
    }
    outcome = await response.json();
  } catch (error) {
    console.error(`Turnstile siteverify failed: ${error instanceof Error ? error.message : String(error)}`);
    return "unavailable";
  }

  const errorCodes = Array.isArray(outcome["error-codes"]) ? outcome["error-codes"] : [];
  if (errorCodes.some((code) => secretErrorCodes.has(code))) {
    console.error(`Turnstile rejected the Worker's secret: ${errorCodes.join(", ")}`);
    return "unavailable";
  }
  const solvedHere = outcome.success === true
    && outcome.hostname === turnstileHostname
    && outcome.action === turnstileAction
    && outcome.cdata === source;
  return solvedHere ? "verified" : "rejected";
}
