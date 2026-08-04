import { normalizeSearchText } from "./search.js";

function searchableEntry(item, containerId, path, translate) {
  const title = translate(item.titleKey);
  const secondaryKey = item.subtitleKey ?? item.descriptionKey;
  const secondary = secondaryKey ? translate(secondaryKey) : "";
  return {
    id: item.id, type: item.type, title, secondary, containerId, path, item,
    normalized: normalizeSearchText(`${title} ${secondary}`),
  };
}

export function buildLibrarySearchIndex(library, collections, translate) {
  const index = [];
  const visited = new Set();
  const visit = (items, containerId, path) => {
    for (const item of items) {
      const destinationPath = item.type === "collection" ? [...path, item.collectionId] : path;
      index.push(searchableEntry(item, containerId, destinationPath, translate));
      if (item.type === "collection" && !visited.has(item.collectionId)) {
        visited.add(item.collectionId);
        visit(collections[item.collectionId]?.items ?? [], item.collectionId, destinationPath);
      }
    }
  };
  visit(library.items, null, []);
  return index;
}

export function searchLibrary(index, query, limit = 12) {
  const normalized = normalizeSearchText(query);
  if (!normalized) return [];
  return index.filter((entry) => entry.normalized.includes(normalized)).slice(0, limit);
}
