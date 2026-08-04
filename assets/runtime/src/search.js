import { getByPath } from "./i18n.js";

export function normalizeSearchText(value) {
  return String(value ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

function collectKeys(value, output = []) {
  if (Array.isArray(value)) value.forEach((item) => collectKeys(item, output));
  else if (value && typeof value === "object") {
    for (const [name, child] of Object.entries(value)) {
      if (/^(title|subtitle|footer|text|caption|label|header|ariaLabel)Key$/.test(name) && typeof child === "string") output.push(child);
      else collectKeys(child, output);
    }
  }
  return output;
}

export function buildSearchIndex(manual, catalog, translate) {
  return manual.sections.map((section) => {
    const title = translate(section.titleKey);
    const texts = collectKeys(section).map((key) => getByPath(catalog, key) ?? translate(key));
    const completeText = [title, ...texts].join(" ");
    return { sectionId: section.id, title, text: completeText, normalized: normalizeSearchText(completeText) };
  });
}

export function searchIndex(index, query, limit = 8) {
  const normalizedQuery = normalizeSearchText(query);
  if (!normalizedQuery) return [];
  return index.filter((entry) => entry.normalized.includes(normalizedQuery)).slice(0, limit).map((entry) => {
    const position = entry.normalized.indexOf(normalizedQuery);
    const start = Math.max(0, position - 45);
    return { ...entry, excerpt: `${start > 0 ? "…" : ""}${entry.text.slice(start, start + 120)}${entry.text.length > start + 120 ? "…" : ""}` };
  });
}
