import { compareSemVer, isSafeRelativePath, manualRoot, RUNTIME_VERSION, SUPPORTED_FORMAT_VERSION } from "./config.js";
import { languageCandidates, languageFallbackChain } from "./i18n.js";

export class ManualLoadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ManualLoadError";
    this.code = code;
  }
}

async function fetchJson(url, code) {
  globalThis.window?.__omniPreviewTrace?.("resource:fetch:start", { code, url: url.href });
  let response;
  try {
    response = await fetch(url);
  } catch (error) {
    throw new ManualLoadError(code, `No se pudo acceder a ${url.pathname}`);
  }
  globalThis.window?.__omniPreviewTrace?.("resource:fetch:response", { code, url: url.href, status: response.status, mimeType: response.headers.get("content-type") });
  if (!response.ok) throw new ManualLoadError(code, `Recurso no disponible (${response.status}): ${url.pathname}`);
  try {
    const json = await response.json();
    globalThis.window?.__omniPreviewTrace?.(code === "MANUAL_INVALID" ? "manual:parse:ok" : "resource:parse:ok", { code, url: url.href });
    return json;
  } catch (error) {
    throw new ManualLoadError(code, `JSON no válido: ${url.pathname}`);
  }
}

export async function loadManualPackage(manualId, requestedLanguage) {
  const root = manualRoot(manualId);
  const manifest = await fetchJson(new URL("manifest.json", root), "MANUAL_NOT_FOUND");
  if (manifest.formatVersion !== SUPPORTED_FORMAT_VERSION) throw new ManualLoadError("FORMAT_INCOMPATIBLE", "Formato de manual no compatible");
  const runtimeComparison = compareSemVer(RUNTIME_VERSION, manifest.minimumRuntimeVersion);
  globalThis.window?.__omniPreviewTrace?.("runtime:version-check", { runtimeVersion: RUNTIME_VERSION, requiredVersion: manifest.minimumRuntimeVersion, comparison: runtimeComparison });
  if (runtimeComparison < 0) {
    throw new ManualLoadError("RUNTIME_INCOMPATIBLE", `Este manual requiere el runtime ${manifest.minimumRuntimeVersion} o posterior`);
  }
  if (!isSafeRelativePath(manifest.entrypoint)) throw new ManualLoadError("MANIFEST_INVALID", "Entrypoint no seguro");
  const manual = await fetchJson(new URL(manifest.entrypoint, root), "MANUAL_INVALID");
  if (manual.id !== manifest.id || manual.formatVersion !== manifest.formatVersion) throw new ManualLoadError("MANUAL_INVALID", "Manifest y manual no coinciden");
  const candidates = languageCandidates(requestedLanguage, manual.languages, manual.defaultLanguage);
  const language = candidates[0] ?? manual.defaultLanguage;
  const languagesToLoad = new Set(candidates);
  const catalogs = {};
  for (const languageCode of languagesToLoad) {
    const contentPath = manual.content[languageCode];
    if (!isSafeRelativePath(contentPath)) throw new ManualLoadError("MANUAL_INVALID", `Ruta de traducción no segura: ${languageCode}`);
    catalogs[languageCode] = await fetchJson(new URL(contentPath, root), "TRANSLATION_MISSING");
  }
  return { root, manifest, manual, catalogs, language, languageChain: languageFallbackChain(requestedLanguage, manual.defaultLanguage) };
}

export async function loadLanguage(root, manual, language, catalogs) {
  if (!manual.languages.includes(language)) throw new ManualLoadError("TRANSLATION_MISSING", `Idioma no disponible: ${language}`);
  if (!catalogs[language]) catalogs[language] = await fetchJson(new URL(manual.content[language], root), "TRANSLATION_MISSING");
  return catalogs[language];
}
