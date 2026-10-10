// What the Guide's feedback form, the app, and Cloudflare/Feedback agree on. The app keeps the same limits in
// Models/App/Feedback/Submission/FeedbackLimits.swift; the Worker's tests check that they match.
export const feedbackEndpoint = "https://justsessions-feedback.noether-lab.workers.dev/feedback";
export const turnstileScriptURL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
// The "JustSessions feedback" Turnstile widget, registered for yangzichao.github.io only.
export const turnstileSiteKey = "0x4AAAAAAFSy820kdLjpbFrF";
export const turnstileAction = "feedback";
export const turnstileHostname = "yangzichao.github.io";

/** Where feedback came from. It is also the widget's cData, so a token solved for one cannot be sent as the other. */
export const feedbackSources = new Set(["website", "app"]);

// Lengths in UTF-16 code units, as JavaScript's `length` counts them.
export const maximumMessageLength = 5000;
export const maximumContactLength = 200;
export const maximumVersionLength = 40;
export const maximumTurnstileTokenLength = 2048;
