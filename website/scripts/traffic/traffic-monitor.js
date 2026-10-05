import { classifyTrafficSource, publishedPages, publishedWebsiteOrigin } from "./traffic-categories.js";

const trafficEndpoint = "https://justsessions-website-traffic.noether-lab.workers.dev/pageview";

/** One anonymous count per page load, independent of gallery interaction. */
export async function recordWebsitePageView(browser) {
  const page = publishedPages.get(browser.location.pathname);
  if (browser.location.origin !== publishedWebsiteOrigin || !page) return false;
  if (browser.navigator.globalPrivacyControl || browser.navigator.doNotTrack === "1" || browser.doNotTrack === "1") return false;
  if (browser.navigator.webdriver) return false;

  const endpoint = new URL(trafficEndpoint);
  endpoint.searchParams.set("page", page);
  endpoint.searchParams.set("source", classifyTrafficSource(browser.document.referrer));
  try {
    const response = await browser.fetch(endpoint.href, {
      method: "POST", credentials: "omit", referrerPolicy: "no-referrer", keepalive: true,
    });
    return response.ok;
  } catch {
    // Statistics must never interrupt navigation, downloads, or the slideshow.
    return false;
  }
}

if (typeof window !== "undefined") void recordWebsitePageView(window);
