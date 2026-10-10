import { turnstileAction, turnstileSiteKey } from "./feedback-contract.js";
import { loadTurnstile } from "./turnstile-loader.js";

// The app's interface languages, as Turnstile names them.
const turnstileLanguages = new Map([["en", "en"], ["zh-Hans", "zh-cn"]]);

/**
 * Runs Turnstile for the app's feedback page, which shows this page in a small web view. Each token, expiry, or error
 * goes to the app's `turnstile` message handler; the app calls `resetVerification()` after using a token. Opened
 * anywhere else, the page does nothing.
 */
export async function startAppVerification(browser, load = loadTurnstile) {
  const appHandler = browser.webkit?.messageHandlers?.turnstile;
  if (!appHandler) return false;
  const post = (event, token) => appHandler.postMessage(token === undefined ? { event } : { event, token });
  const parameters = new URL(browser.location.href).searchParams;

  let turnstile;
  try {
    turnstile = await load(browser);
  } catch {
    post("error");
    return false;
  }
  const widgetID = turnstile.render(browser.document.getElementById("verification"), {
    sitekey: turnstileSiteKey,
    action: turnstileAction,
    cData: "app",
    theme: parameters.get("theme") === "dark" ? "dark" : "light",
    language: turnstileLanguages.get(parameters.get("language")) ?? "auto",
    callback: (token) => post("verified", token),
    "expired-callback": () => post("expired"),
    "error-callback": () => post("error"),
  });
  browser.resetVerification = () => turnstile.reset(widgetID);
  return true;
}

if (typeof window !== "undefined") void startAppVerification(window);
