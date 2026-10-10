import { maximumVersionLength } from "./feedback-contract.js";

// Such as "1.1.0 (98)", "1.1.0-3-gf45492c (0)", "development build", or "26.0.1".
const versionPattern = /^[0-9A-Za-z .()-]+$/;

/**
 * The app and macOS versions the app's Send feedback put in the Guide's address, such as
 * `guide.html?appVersion=1.1.0%20(98)&macOSVersion=26.5#feedback`, or null when the visitor came another way or
 * either one is not a version the Worker accepts.
 */
export function readAppVersions(search) {
  const parameters = new URLSearchParams(search);
  const appVersion = parameters.get("appVersion");
  const macOSVersion = parameters.get("macOSVersion");
  return isVersion(appVersion) && isVersion(macOSVersion) ? { appVersion, macOSVersion } : null;
}

export function isVersion(value) {
  return typeof value === "string" && value.length <= maximumVersionLength && versionPattern.test(value);
}
