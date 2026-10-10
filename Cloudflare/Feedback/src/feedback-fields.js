import { isVersion } from "../../../website/scripts/feedback/app-versions.js";
import {
  feedbackSources, maximumContactLength, maximumMessageLength, maximumTurnstileTokenLength,
} from "../../../website/scripts/feedback/feedback-contract.js";

const allowedFields = new Set(["message", "contact", "source", "appVersion", "macOSVersion", "turnstileToken"]);

/**
 * The feedback to store, or null when the body is not exactly what the Guide's form sends: a JSON object with a
 * message, an optional contact, its source, the app and macOS versions only when the app opened the form, and a
 * Turnstile token.
 */
export function readFeedbackFields(body) {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return null;
  if (Object.keys(body).some((field) => !allowedFields.has(field))) return null;

  const message = trimmedText(body.message);
  if (!message || message.length > maximumMessageLength) return null;

  const contact = body.contact === undefined ? "" : trimmedText(body.contact);
  if (contact === null || contact.length > maximumContactLength) return null;

  if (!feedbackSources.has(body.source)) return null;
  const sentByApp = body.source === "app";
  if (sentByApp !== (body.appVersion !== undefined) || sentByApp !== (body.macOSVersion !== undefined)) return null;
  if (sentByApp && !(isVersion(body.appVersion) && isVersion(body.macOSVersion))) return null;

  const turnstileToken = body.turnstileToken;
  if (typeof turnstileToken !== "string" || !turnstileToken || turnstileToken.length > maximumTurnstileTokenLength) return null;

  return {
    message,
    contact: contact || null,
    source: body.source,
    appVersion: sentByApp ? body.appVersion : null,
    macOSVersion: sentByApp ? body.macOSVersion : null,
    turnstileToken,
  };
}

function trimmedText(value) {
  return typeof value === "string" ? value.trim() : null;
}
