import { recordDailyUpdateCheck } from "./daily-update-check-counts.js";
import { readAppVersionFromSparkleUserAgent } from "./sparkle-app-version.js";

// The release workflow attaches appcast.xml to every GitHub release; this always resolves to the newest one.
export const githubAppcastURL = "https://github.com/yangzichao/JustSessions/releases/latest/download/appcast.xml";

export default {
    /**
     * Counts a JustSessions update check, then sends Sparkle on to the appcast on GitHub.
     * @param {Request} request
     * @param {{ UPDATE_CHECKS_DATABASE: D1Database }} env
     * @param {ExecutionContext} ctx
     */
    async fetch(request, env, ctx) {
        if (new URL(request.url).pathname !== "/appcast.xml") {
            return new Response("Not found\n", { status: 404 });
        }
        if (request.method !== "GET" && request.method !== "HEAD") {
            return new Response("Method not allowed\n", { status: 405, headers: { Allow: "GET, HEAD" } });
        }

        const appVersion = readAppVersionFromSparkleUserAgent(request.headers.get("User-Agent"));
        if (request.method === "GET" && appVersion !== null) {
            ctx.waitUntil(recordDailyUpdateCheckWithoutBlockingUpdates(env.UPDATE_CHECKS_DATABASE, appVersion));
        }

        return new Response(null, {
            status: 302,
            headers: { Location: githubAppcastURL, "Cache-Control": "no-store" },
        });
    },
};

/** A failed count must never stop Sparkle from finding an update, so the error is only logged. */
async function recordDailyUpdateCheckWithoutBlockingUpdates(database, appVersion) {
    try {
        await recordDailyUpdateCheck(database, appVersion, new Date());
    } catch (error) {
        console.error(`Could not record an update check: ${error instanceof Error ? error.message : String(error)}`);
    }
}
