import { turnstileScriptURL } from "./feedback-contract.js";

const loadedCallbackName = "justSessionsTurnstileLoaded";
let loadingTurnstile = null;

/**
 * Cloudflare's Turnstile script, added to the page the first time something needs it. Cloudflare asks for it to be
 * loaded from its own URL, never copied or proxied, so it stays current.
 */
export function loadTurnstile(browser) {
  loadingTurnstile ??= new Promise((resolve, reject) => {
    const script = browser.document.createElement("script");
    browser[loadedCallbackName] = () => resolve(browser.turnstile);
    script.src = `${turnstileScriptURL}&onload=${loadedCallbackName}`;
    script.async = true;
    script.onerror = () => {
      loadingTurnstile = null;
      script.remove();
      reject(new Error("Turnstile could not load"));
    };
    browser.document.head.append(script);
  });
  return loadingTurnstile;
}
