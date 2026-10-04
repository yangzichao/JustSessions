// Sparkle sends `JustSessions/<CFBundleShortVersionString> Sparkle/<Sparkle version>` with each update check.
const sparkleUserAgentPattern = /^JustSessions\/(\d{1,4}\.\d{1,4}\.\d{1,4}) Sparkle\/[0-9A-Za-z.\-]{1,32}$/;

/**
 * The app version of a JustSessions update check, or null for any other client.
 * Only versions in this exact form are kept, so the counts never hold free-form text from a request.
 * @param {string | null} userAgent
 * @returns {string | null}
 */
export function readAppVersionFromSparkleUserAgent(userAgent) {
    const match = userAgent?.match(sparkleUserAgentPattern);
    return match ? match[1] : null;
}
