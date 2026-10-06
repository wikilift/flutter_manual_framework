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
  return [...new Set([...languageFallbackChain(requested, defaultLanguage), ...languageFallbackChain(defaultLanguage), "en", ...[...available].sort()])].filter((item) => available.includes(item));
}

export function createTranslator(catalogs, language, defaultLanguage, development = true) {
  return (key) => {
    for (const candidate of languageCandidates(language, Object.keys(catalogs), defaultLanguage)) {
      const value = getByPath(catalogs[candidate], key);
      if (typeof value === "string" && value.trim()) return value;
    }
    console.warn(`[i18n] Falta la traducción: ${key} (${language})`);
    return development ? `⟦${key}⟧` : key;
  };
}

export function createOptionalTranslator(catalogs, language, defaultLanguage) {
  return (key) => {
    if (!key) return "";
    for (const candidate of languageCandidates(language, Object.keys(catalogs), defaultLanguage)) {
      const value = getByPath(catalogs[candidate], key);
      if (typeof value === "string" && value.trim()) return value.trim();
    }
    return "";
  };
}
