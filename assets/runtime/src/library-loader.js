import { isSafeRelativePath, isValidId } from "./config.js";
import { languageCandidates } from "./i18n.js";

export class LibraryLoadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "LibraryLoadError";
    this.code = code;
  }
}

export function libraryRoot() {
  return new URL("../../library/", import.meta.url);
}

async function fetchJson(url, code) {
  globalThis.window?.__omniPreviewTrace?.("resource:fetch:start", { code, url: url.href });
  let response;
  try {
    response = await fetch(url);
  } catch (error) {
    throw new LibraryLoadError(code, `No se pudo acceder a ${url.pathname}`);
  }
  globalThis.window?.__omniPreviewTrace?.("resource:fetch:response", { code, url: url.href, status: response.status, mimeType: response.headers.get("content-type") });
  if (!response.ok) throw new LibraryLoadError(code, `Recurso no disponible (${response.status}): ${url.pathname}`);
  try {
    return await response.json();
  } catch (error) {
    throw new LibraryLoadError(code, `JSON no válido: ${url.pathname}`);
  }
}

export async function loadLibraryPackage(requestedLanguage) {
  const root = libraryRoot();
  const library = await fetchJson(new URL("library.json", root), "LIBRARY_NOT_FOUND");
  if (library.formatVersion !== 1 || !isValidId(library.id)) throw new LibraryLoadError("LIBRARY_INVALID", "Formato o ID de biblioteca no válido");
  const collections = {};
  for (const [collectionId, path] of Object.entries(library.collections ?? {})) {
    if (!isValidId(collectionId) || !isSafeRelativePath(path)) throw new LibraryLoadError("LIBRARY_INVALID", `Colección no segura: ${collectionId}`);
    const collection = await fetchJson(new URL(path, root), "COLLECTION_MISSING");
    if (collection.id !== collectionId) throw new LibraryLoadError("COLLECTION_INVALID", `La colección ${collectionId} no coincide con su fichero`);
    collections[collectionId] = collection;
  }
  const language = languageCandidates(requestedLanguage, library.languages, library.defaultLanguage)[0] ?? library.defaultLanguage;
  const catalogs = {};
  await Promise.all(languageCandidates(requestedLanguage, library.languages, library.defaultLanguage).map(async (code) => {
    const path = library.content[code];
    if (!isSafeRelativePath(path)) throw new LibraryLoadError("LIBRARY_INVALID", `Ruta de traducción no segura: ${code}`);
    catalogs[code] = await fetchJson(new URL(path, root), "TRANSLATION_MISSING");
  }));
  return { root, library, collections, catalogs, language };
}

export async function loadLibraryLanguage(packageData, language) {
  if (!packageData.library.languages.includes(language)) throw new LibraryLoadError("TRANSLATION_MISSING", `Idioma no disponible: ${language}`);
  if (!packageData.catalogs[language]) {
    packageData.catalogs[language] = await fetchJson(new URL(packageData.library.content[language], packageData.root), "TRANSLATION_MISSING");
  }
  return packageData.catalogs[language];
}

export function findCollectionPath(library, collections, targetId) {
  const queue = library.items.filter((item) => item.type === "collection").map((item) => ({ id: item.collectionId, path: [item.collectionId] }));
  const visited = new Set();
  while (queue.length) {
    const current = queue.shift();
    if (current.id === targetId) return current.path;
    if (visited.has(current.id)) continue;
    visited.add(current.id);
    for (const item of collections[current.id]?.items ?? []) {
      if (item.type === "collection") queue.push({ id: item.collectionId, path: [...current.path, item.collectionId] });
    }
  }
  return null;
}

export function findVideo(library, collections, videoId, preferredCollection = null) {
  const candidates = Object.entries(collections).flatMap(([collectionId, collection]) => (
    collection.items.filter((item) => item.type === "video" && item.id === videoId).map((item) => ({ item, collectionId }))
  ));
  const selected = candidates.find((candidate) => candidate.collectionId === preferredCollection) ?? candidates[0];
  return selected ? { ...selected, path: findCollectionPath(library, collections, selected.collectionId) ?? [selected.collectionId] } : null;
}
