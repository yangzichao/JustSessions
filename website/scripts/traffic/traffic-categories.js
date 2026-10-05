export const publishedWebsiteOrigin = "https://yangzichao.github.io";
export const publishedPages = new Map([
  ["/JustSessions", "home"],
  ["/JustSessions/", "home"],
  ["/JustSessions/index.html", "home"],
  ["/JustSessions/guide.html", "guide"],
]);
export const trafficSourceCategories = new Set([
  "direct", "internal", "github", "google", "bing", "duckduckgo", "baidu",
  "reddit", "hacker-news", "x", "linkedin", "other",
]);

/** Reduce the referrer to a fixed category; never send its URL or hostname. */
export function classifyTrafficSource(referrer) {
  if (!referrer) return "direct";
  let referringURL;
  try { referringURL = new URL(referrer); } catch { return "other"; }
  if (referringURL.origin === publishedWebsiteOrigin) return "internal";
  const hostname = referringURL.hostname;
  const matchesHost = (domain) => hostname === domain || hostname.endsWith(`.${domain}`);
  for (const domain of ["github.com", "bing.com", "duckduckgo.com", "baidu.com", "reddit.com", "linkedin.com"]) {
    if (matchesHost(domain)) return domain.split(".")[0];
  }
  if (/(^|\.)google\.[a-z.]+$/.test(hostname)) return "google";
  if (hostname === "news.ycombinator.com") return "hacker-news";
  if (matchesHost("x.com") || matchesHost("twitter.com")) return "x";
  return "other";
}
