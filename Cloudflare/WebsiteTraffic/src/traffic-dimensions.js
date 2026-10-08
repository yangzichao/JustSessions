export function classifyDevice(userAgent) {
  if (/ipad|tablet|android(?!.*mobile)/i.test(userAgent)) return "tablet";
  return /mobile|iphone|ipod/i.test(userAgent) ? "mobile" : "desktop";
}

export function countryCategory(country) {
  return typeof country === "string" && /^[A-Z]{2}$/.test(country) && country !== "XX" ? country : "unknown";
}

export function isKnownAutomatedClient(userAgent) {
  return /bot|crawler|spider|headless|curl|wget|python|httpclient|lighthouse/i.test(userAgent);
}
