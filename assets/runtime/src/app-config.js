import { isValidId } from "./config.js";

export function parseRuntimeOptions(search) {
  const parameters = new URLSearchParams(search);
  const manualId = parameters.get("manualId");
  const collectionId = parameters.get("collection");
  const videoId = parameters.get("video");
  const language = parameters.get("language") || null;
  const devMode = parameters.get("dev") === "1";
  const printMode = parameters.get("print") === "1";
  const apiBaseUrl = safePublicApiBaseUrl(parameters.get("apiBaseUrl") ?? parameters.get("publicApiBaseUrl"));
  const requestedPrintLayout = parameters.get("printLayout");
  const printLayout = requestedPrintLayout === "continuous" ? "continuous" : "paged";
  const requestedShell = parameters.get("shell");
  const shellMode = requestedShell === "embedded" ? "embedded" : "standalone";
  let route = { view: "library" };
  if (manualId && isValidId(manualId)) route = { view: "manual", manualId };
  else if (videoId && isValidId(videoId)) route = { view: "video", videoId, collectionId: isValidId(collectionId) ? collectionId : null };
  else if (collectionId && isValidId(collectionId)) route = { view: "collection", collectionId };
  return { language, devMode, printMode, printLayout, route, shellMode, apiBaseUrl, publicApiBaseUrl: apiBaseUrl };
}

function safePublicApiBaseUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (!["http:", "https:"].includes(url.protocol)) return null;
    url.username = "";
    url.password = "";
    url.hash = "";
    url.search = "";
    return url.href.replace(/\/$/, "");
  } catch {
    return null;
  }
}
