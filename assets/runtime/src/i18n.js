export function getByPath(source, path) {
  if (!source || typeof path !== "string") return undefined;
  if (Object.prototype.hasOwnProperty.call(source, path)) return source[path];
  return path.split(".").reduce((value, part) => (
    value && Object.prototype.hasOwnProperty.call(value, part) ? value[part] : undefined
  ), source);
}

export function languageFallbackChain(requested, defaultLanguage) {
  const normalized = String(requested ?? "").replace("_", "-");
  const base = normalized.split("-")[0];
  return [...new Set([normalized, base, defaultLanguage])].filter(Boolean);
}

export function languageCandidates(requested, available, defaultLanguage) {
  return languageFallbackChain(requested, defaultLanguage).filter((item) => available.includes(item));
}

export function createTranslator(catalogs, language, defaultLanguage, development = true) {
  return (key) => {
    const preferred = getByPath(catalogs[language], key);
    if (typeof preferred === "string") return preferred;
    const fallback = getByPath(catalogs[defaultLanguage], key);
    if (typeof fallback === "string") return fallback;
    console.warn(`[i18n] Falta la traducción: ${key} (${language})`);
    return development ? `⟦${key}⟧` : key;
  };
}

export function createOptionalTranslator(catalogs, language, defaultLanguage) {
  return (key) => {
    if (!key) return "";
    const preferred = getByPath(catalogs[language], key);
    if (typeof preferred === "string" && preferred.trim()) return preferred.trim();
    const fallback = getByPath(catalogs[defaultLanguage], key);
    if (typeof fallback === "string" && fallback.trim()) return fallback.trim();
    return "";
  };
}
