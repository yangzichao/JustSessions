import { publishedWebsiteOrigin } from "../../../website/scripts/traffic/traffic-categories.js";
import { readBoundedRequestText } from "./bounded-request-body.js";
import { readFeedbackFields } from "./feedback-fields.js";
import { verifyTurnstileToken } from "./turnstile-verification.js";

// The longest message, escaped as JSON, with room for the other fields.
const maximumBodyBytes = 64 * 1024;
const responseHeaders = {
  "Access-Control-Allow-Origin": publishedWebsiteOrigin,
  "Cache-Control": "no-store",
  "Vary": "Origin",
};

export default {
  /**
   * Stores feedback from the Guide's form, opened on the website or by the app, after Cloudflare Turnstile confirms a
   * person sent it. Only the message, the optional contact, its source, and the app's versions are kept; never an IP
   * address or user agent.
   * @param {Request} request
   * @param {{ FEEDBACK_DATABASE: D1Database, FEEDBACK_RATE_LIMITER: RateLimit, TURNSTILE_SECRET_KEY: string }} env
   */
  async fetch(request, env) {
    if (new URL(request.url).pathname !== "/feedback") return answer(404);
    // Only the published website sends feedback, so requests from other sites or without an Origin are refused.
    if (request.headers.get("Origin") !== publishedWebsiteOrigin) return answer(403);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: {
        ...responseHeaders,
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Max-Age": "86400",
      } });
    }
    if (request.method !== "POST") return answer(405, undefined, { Allow: "POST, OPTIONS" });
    if (request.headers.get("Content-Type")?.split(";")[0].trim().toLowerCase() !== "application/json") return answer(415);
    const bodyText = await readBoundedRequestText(request, maximumBodyBytes);
    if (bodyText === null) return answer(413);
    let body;
    try { body = JSON.parse(bodyText); } catch { return answer(400, "invalid-feedback"); }
    const feedback = readFeedbackFields(body);
    if (!feedback) return answer(400, "invalid-feedback");

    // The address only selects a short-lived counter; it is never stored.
    const remoteIP = request.headers.get("CF-Connecting-IP");
    const { success: withinRateLimit } = await env.FEEDBACK_RATE_LIMITER.limit({ key: remoteIP ?? "unknown" });
    if (!withinRateLimit) return answer(429, "too-many-requests");

    const verification = await verifyTurnstileToken({
      token: feedback.turnstileToken, source: feedback.source, secret: env.TURNSTILE_SECRET_KEY, remoteIP,
    });
    if (verification === "rejected") return answer(403, "verification-failed");
    if (verification !== "verified") return answer(503, "unavailable");

    try {
      await env.FEEDBACK_DATABASE.prepare(`
        INSERT INTO feedback (source, message, contact, app_version, macos_version)
        VALUES (?, ?, ?, ?, ?)
      `).bind(feedback.source, feedback.message, feedback.contact, feedback.appVersion, feedback.macOSVersion).run();
    } catch (error) {
      console.error(`Could not store feedback: ${error instanceof Error ? error.message : String(error)}`);
      return answer(503, "unavailable");
    }
    return answer(201, "sent");
  },

  async scheduled(_event, env) {
    await env.FEEDBACK_DATABASE.prepare(
      "DELETE FROM feedback WHERE received_at < strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '-365 days')",
    ).run();
  },
};

/** A JSON `{ "result": … }` the website reads, or an empty response for requests it never makes. */
function answer(status, result, extraHeaders = {}) {
  if (result === undefined) return new Response(null, { status, headers: { ...responseHeaders, ...extraHeaders } });
  return new Response(JSON.stringify({ result }), {
    status, headers: { ...responseHeaders, "Content-Type": "application/json; charset=utf-8", ...extraHeaders },
  });
}
