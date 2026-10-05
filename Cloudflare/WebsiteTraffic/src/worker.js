import { publishedPages, publishedWebsiteOrigin, trafficSourceCategories } from "../../../website/scripts/traffic/traffic-categories.js";
import { classifyDevice, countryCategory, isKnownAutomatedClient } from "./traffic-dimensions.js";

const pageNames = new Set(publishedPages.values());
const responseHeaders = {
  "Access-Control-Allow-Origin": publishedWebsiteOrigin,
  "Cache-Control": "no-store",
  "Vary": "Origin",
};

export default {
  async fetch(request, env) {
    const requestURL = new URL(request.url);
    if (requestURL.pathname !== "/pageview") return new Response(null, { status: 404 });
    if (request.headers.get("Origin") !== publishedWebsiteOrigin) return new Response(null, { status: 403 });
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: {
        ...responseHeaders, "Access-Control-Allow-Methods": "POST", "Access-Control-Max-Age": "86400",
      } });
    }
    if (request.method !== "POST") return new Response(null, { status: 405, headers: { ...responseHeaders, Allow: "POST, OPTIONS" } });

    const page = requestURL.searchParams.get("page");
    const source = requestURL.searchParams.get("source");
    if (!pageNames.has(page) || !trafficSourceCategories.has(source)
        || requestURL.searchParams.getAll("page").length !== 1 || requestURL.searchParams.getAll("source").length !== 1
        || [...requestURL.searchParams.keys()].some((key) => key !== "page" && key !== "source")) {
      return new Response(null, { status: 400, headers: responseHeaders });
    }
    const userAgent = request.headers.get("User-Agent") || "";
    if (!userAgent || isKnownAutomatedClient(userAgent) || request.headers.get("Sec-GPC") === "1" || request.headers.get("DNT") === "1") {
      return new Response(null, { status: 204, headers: responseHeaders });
    }

    try {
      await env.WEBSITE_TRAFFIC_DATABASE.prepare(`
        INSERT INTO daily_website_traffic (utc_day, page, source, country, device, page_views)
        VALUES (?, ?, ?, ?, ?, 1)
        ON CONFLICT (utc_day, page, source, country, device)
        DO UPDATE SET page_views = page_views + 1
      `).bind(new Date().toISOString().slice(0, 10), page, source, countryCategory(request.cf?.country), classifyDevice(userAgent)).run();
      return new Response(null, { status: 204, headers: responseHeaders });
    } catch {
      console.error("Could not record aggregate website traffic");
      return new Response(null, { status: 503, headers: responseHeaders });
    }
  },

  async scheduled(_event, env) {
    await env.WEBSITE_TRAFFIC_DATABASE.prepare("DELETE FROM daily_website_traffic WHERE utc_day < date('now', '-180 days')").run();
  },
};
