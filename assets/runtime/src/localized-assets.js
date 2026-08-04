import { isSafeRelativePath } from "./config.js";

export function isLocalizedAssetTemplate(value) {
  if (!isSafeRelativePath(value)) return false;
  return (value.match(/\{lang\}/g) ?? []).length === 1;
}

export function localizedAssetCandidates(template, languageChain) {
  if (!isLocalizedAssetTemplate(template)) return [];
  return [...new Set(languageChain)]
    .filter(Boolean)
    .map((language) => template.replace("{lang}", language))
    .filter(isSafeRelativePath);
}

export function collectLocalizedAssetTemplates(value, templates = new Set()) {
  if (Array.isArray(value)) {
    value.forEach((item) => collectLocalizedAssetTemplates(item, templates));
    return templates;
  }
  if (!value || typeof value !== "object") return templates;
  Object.entries(value).forEach(([name, child]) => {
    if (name === "localizedSrc" && typeof child === "string") templates.add(child);
    collectLocalizedAssetTemplates(child, templates);
  });
  return templates;
}

export function probeLocalImage(url) {
  return new Promise((resolve) => {
    const image = new Image();
    image.onload = () => resolve(true);
    image.onerror = () => resolve(false);
    image.src = url;
  });
}

export async function resolveLocalizedAssets(document, root, languageChain, options = {}) {
  const probe = options.probe ?? probeLocalImage;
  const resolved = new Map();
  for (const template of collectLocalizedAssetTemplates(document)) {
    let match = null;
    const candidates = localizedAssetCandidates(template, languageChain);
    for (const path of candidates) {
      const url = new URL(path, root).href;
      if (await probe(url)) {
        match = url;
        break;
      }
    }
    resolved.set(template, match);
    if (!match && options.devMode) {
      console.warn(`[assets] No existe ninguna variante localizada: ${template} (${candidates.join(" -> ")})`);
    }
  }
  return resolved;
}
