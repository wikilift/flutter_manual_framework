import { parseRuntimeOptions } from "./app-config.js";
import { isValidId } from "./config.js";
import { createOptionalTranslator, createTranslator } from "./i18n.js";
import { loadLanguage, loadManualPackage, ManualLoadError } from "./loader.js";
import { findCollectionPath, findVideo, loadLibraryLanguage, loadLibraryPackage, LibraryLoadError } from "./library-loader.js";
import { buildLibrarySearchIndex, searchLibrary } from "./library-search.js";
import { renderLibraryPage, renderVideoPage } from "./library-renderer.js";
import { createNavigationController, routeUrl } from "./navigation.js";
import { renderFatal, clear, element } from "./dom.js";
import { renderManual } from "./renderer.js";
import { buildSearchIndex, searchIndex } from "./search.js";
import { getState, setState } from "./state.js";
import { hashSection, navigateHash } from "./router.js";
import { resolveLocalizedAssets } from "./localized-assets.js";
import { bindSingleActiveOverlay, markerDetailNodes, markerLegendContent, overlayArrowGeometry, overlayArrowHeadPath, overlayColor, overlayOpacity, overlayPath, overlayPoints, overlayStrokeWidth, overlayTone, overlayTooltipClass, rectangleFillStyle, rectangleSvgRadius, rectangleTextNodes, scaledOverlayCssPx, syncAnnotationLayer } from "./components/shared.js";

const nodes = {
  app: document.querySelector("#app"), content: document.querySelector("#manual-content"), toc: document.querySelector("#toc"),
  title: document.querySelector("#header-title"), language: document.querySelector("#language-select"), back: document.querySelector("#back-button"),
  drawer: document.querySelector("#sidebar"), drawerButton: document.querySelector("#drawer-button"), drawerClose: document.querySelector("#drawer-close"),
  backdrop: document.querySelector("#drawer-backdrop"), searchPanel: document.querySelector("#search-panel"), searchButton: document.querySelector("#search-button"),
  searchClose: document.querySelector("#search-close"), searchForm: document.querySelector("#search-form"), searchInput: document.querySelector("#search-input"),
  searchResults: document.querySelector("#search-results"), lightbox: document.querySelector("#lightbox"), lightboxImage: document.querySelector("#lightbox-image"), lightboxStage: document.querySelector("#lightbox-stage"),
  lightboxMarkers: document.querySelector("#lightbox-markers"), lightboxCaption: document.querySelector("#lightbox-caption"), lightboxClose: document.querySelector("#lightbox-close"),
};

const options = parseRuntimeOptions(window.location.search);
const previewTrace = (stage, detail = {}) => { if (options.devMode) window.__omniPreviewTrace?.(stage, detail); };
document.body.classList.toggle("print-mode", options.printMode);
document.body.classList.toggle("runtime-embedded", options.shellMode === "embedded");
document.documentElement.classList.toggle("omni-print-mode", options.printMode);
document.body.classList.toggle("omni-print-mode", options.printMode);
document.documentElement.classList.toggle("omni-print-continuous", options.printMode && options.printLayout === "continuous");
document.body.classList.toggle("omni-print-continuous", options.printMode && options.printLayout === "continuous");
document.documentElement.classList.toggle("omni-print-paged", options.printMode && options.printLayout !== "continuous");
document.body.classList.toggle("omni-print-paged", options.printMode && options.printLayout !== "continuous");
const DEFAULT_UI = Object.freeze({
  ui: {
    back: "Volver",
    search: "Buscar",
    close_search: "Cerrar búsqueda",
    index: "Índice",
    language: "Idioma",
    no_results: "No se encontraron resultados",
    asset_unavailable: "Imagen no disponible.",
    video_unavailable: "Este vídeo es opcional y no está instalado en el dispositivo.",
    video_connection_unavailable: "Conexión no disponible",
    video_play: "Reproducir vídeo",
    video_unsupported: "Este dispositivo no puede reproducir el vídeo.",
    annotation_mode: "Modo anotación",
    annotation_instruction: "Pulse sobre la imagen para obtener coordenadas.",
    copy_json: "Copiar JSON",
    copied: "JSON copiado",
    copy_fallback: "Seleccione y copie manualmente el JSON mostrado.",
    types: { manual: "Manual", collection: "Colección", video: "Vídeo" },
  },
});
let libraryData;
let manualData;
let libraryTranslator;
let manualTranslator;
let manualOptionalTranslator;
let manualSearchEntries = [];
let librarySearchEntries = [];
let sectionObserver;
let focusBeforeOverlay;
let navigation;
let localizedAssets = new Map();
let requestedLanguage = options.language ?? navigator.language;
let lightboxOverlayActivation;

function libraryAssetUrl(path) {
  return new URL(path, libraryData.root).href;
}

function manualAssetUrl(source) {
  if (typeof source === "string") return new URL(source, manualData.root).href;
  if (source?.localizedSrc) return localizedAssets.get(source.localizedSrc) ?? null;
  if (source?.src) return new URL(source.src, manualData.root).href;
  return null;
}

function defaultUi(key) {
  const value = key.split(".").reduce((current, part) => current && typeof current === "object" ? current[part] : undefined, DEFAULT_UI);
  return typeof value === "string" ? value : key;
}

function ui(key) { return libraryTranslator?.(key) ?? defaultUi(key); }

function rectangleBorderWidth(overlayData) {
  return Number.isFinite(overlayData.borderWidth) && overlayData.borderWidth > 0 ? overlayData.borderWidth : 2;
}

function overlayAnimationClass(overlayData) {
  return overlayData.animation === "pulse" ? "annotation-overlay-pulse" : "";
}

function openLightbox(source, legacyAlt, legacyCaption) {
  const { src, alt, caption, overlays = [] } = typeof source === "string" ? { src: source, alt: legacyAlt, caption: legacyCaption, overlays: [] } : source;
  focusBeforeOverlay = document.activeElement;
  nodes.lightboxImage.src = src;
  nodes.lightboxImage.alt = alt;
  lightboxOverlayActivation?.dispose();
  lightboxOverlayActivation = null;
  nodes.lightboxStage.querySelectorAll(".annotation-marker").forEach((node) => node.remove());
  nodes.lightboxStage.querySelectorAll(".annotation-rectangle-button").forEach((node) => node.remove());
  nodes.lightboxStage.querySelector(".annotation-layer")?.remove();
  nodes.lightboxStage.querySelector(".annotation-overlay-svg")?.remove();
  nodes.lightboxMarkers.replaceChildren();
  const activationEntries = [];
  const overlayLayer = element("div", { className: "annotation-layer" });
  const overlaySvg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  overlaySvg.setAttribute("class", "annotation-overlay-svg");
  overlaySvg.setAttribute("viewBox", "0 0 100 100");
  overlaySvg.setAttribute("preserveAspectRatio", "none");
  overlaySvg.setAttribute("aria-hidden", "true");
  overlayLayer.append(overlaySvg);
  nodes.lightboxStage.append(overlayLayer);
  overlays.forEach((overlayData, index) => {
    const detailId = `lightbox-annotation-detail-${overlayData.id}-${index}`;
    if (overlayData.type === "rectangle") {
      if (overlayData.animation === "pulse") {
        const halo = document.createElementNS("http://www.w3.org/2000/svg", "rect");
        halo.setAttribute("class", `annotation-rectangle-halo annotation-overlay-halo annotation-tone-${overlayTone(overlayData)}`);
        halo.setAttribute("x", String(overlayData.x));
        halo.setAttribute("y", String(overlayData.y));
        halo.setAttribute("width", String(overlayData.width));
        halo.setAttribute("height", String(overlayData.height));
        const haloRadius = rectangleSvgRadius(overlayData);
        if (haloRadius !== undefined) halo.setAttribute("rx", String(haloRadius));
        halo.setAttribute("style", `${rectangleFillStyle(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData) + 5, 7, 2, 24)}`);
        overlaySvg.append(halo);
      }
      const rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      rect.setAttribute("class", `annotation-rectangle annotation-tone-${overlayTone(overlayData)} ${overlayAnimationClass(overlayData)}`);
      rect.setAttribute("x", String(overlayData.x));
      rect.setAttribute("y", String(overlayData.y));
      rect.setAttribute("width", String(overlayData.width));
      rect.setAttribute("height", String(overlayData.height));
      const radius = rectangleSvgRadius(overlayData);
      if (radius !== undefined) rect.setAttribute("rx", String(radius));
      rect.setAttribute("style", `${rectangleFillStyle(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData), rectangleBorderWidth(overlayData), 1, 16)}`);
      overlaySvg.append(rect);
      const trigger = element("button", { type: "button", className: `annotation-rectangle-button annotation-tone-${overlayTone(overlayData)}`, style: `--annotation-x:${overlayData.x}%;--annotation-y:${overlayData.y}%;--annotation-width:${overlayData.width}%;--annotation-height:${overlayData.height}%`, dataset: { annotationIndex: String(index), overlayType: "rectangle" }, "aria-label": `${overlayData.number}. ${overlayData.label}`, "aria-controls": detailId, "aria-expanded": "false", "aria-describedby": overlayData.description ? detailId : undefined }, [...rectangleTextNodes(overlayData), element("span", { id: detailId, className: `annotation-label ${overlayTooltipClass(overlayData)}` }, markerDetailNodes(overlayData))]);
      overlayLayer.append(trigger);
      const legendButton = overlayData.showLegend === false ? null : element("button", { type: "button", className: `annotation-tone-${overlayTone(overlayData)}` }, markerLegendContent(overlayData));
      const legendItem = legendButton ? element("li", { className: `annotation-tone-${overlayTone(overlayData)} annotation-type-rectangle` }, [legendButton]) : null;
      activationEntries.push({ id: overlayData.id, trigger, visual: rect, legendTrigger: legendButton, legendItem });
      if (legendItem) nodes.lightboxMarkers.append(legendItem);
      return;
    }
    if (["line", "arrow", "route"].includes(overlayData.type)) {
      const points = overlayPoints(overlayData);
      if (points.length < 2) return;
      const geometry = overlayArrowGeometry(overlayData);
      const shaftPath = overlayPath(geometry.shaftPoints);
      if (overlayData.animation === "pulse") {
        const halo = document.createElementNS("http://www.w3.org/2000/svg", "path");
        halo.setAttribute("class", `annotation-vector-halo annotation-overlay-halo annotation-vector-${overlayData.type} annotation-tone-${overlayTone(overlayData)}`);
        halo.setAttribute("d", shaftPath);
        halo.setAttribute("style", `stroke:${overlayColor(overlayData)};opacity:${overlayOpacity(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData) + 6, 9, 3, 28)}`);
        overlaySvg.append(halo);
        [geometry.startHead, geometry.endHead].filter(Boolean).forEach((head) => {
          const haloHead = document.createElementNS("http://www.w3.org/2000/svg", "path");
          haloHead.setAttribute("class", `annotation-arrow-head-halo annotation-overlay-halo annotation-tone-${overlayTone(overlayData)}`);
          haloHead.setAttribute("d", overlayArrowHeadPath(head));
          haloHead.setAttribute("style", `stroke:${overlayColor(overlayData)};opacity:${overlayOpacity(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData) + 6, 9, 3, 28)}`);
          overlaySvg.append(haloHead);
        });
      }
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute("class", `annotation-vector annotation-vector-${overlayData.type} annotation-tone-${overlayTone(overlayData)} ${overlayAnimationClass(overlayData)}`);
      path.setAttribute("d", shaftPath);
      path.setAttribute("style", `stroke:${overlayColor(overlayData)};opacity:${overlayOpacity(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData), 3, 1, 16)}`);
      overlaySvg.append(path);
      [geometry.startHead, geometry.endHead].filter(Boolean).forEach((head) => {
        const headPath = document.createElementNS("http://www.w3.org/2000/svg", "path");
        headPath.setAttribute("class", `annotation-arrow-head annotation-tone-${overlayTone(overlayData)} ${overlayAnimationClass(overlayData)}`);
        headPath.setAttribute("d", overlayArrowHeadPath(head));
        headPath.setAttribute("style", `fill:${overlayColor(overlayData)};stroke:${overlayColor(overlayData)};opacity:${overlayOpacity(overlayData)}`);
        overlaySvg.append(headPath);
      });
      if (overlayData.showLegend !== false) {
        const legendButton = element("button", { type: "button", className: `annotation-tone-${overlayTone(overlayData)}` }, markerLegendContent(overlayData));
        const legendItem = element("li", { className: `annotation-tone-${overlayTone(overlayData)} annotation-type-${overlayData.type}` }, [legendButton]);
        nodes.lightboxMarkers.append(legendItem);
      }
      return;
    }
    const marker = element("button", { type: "button", className: `annotation-marker annotation-tone-${overlayTone(overlayData)} ${overlayAnimationClass(overlayData)}`, style: `--annotation-x:${overlayData.x}%;--annotation-y:${overlayData.y}%;--annotation-color:${overlayColor(overlayData)}`, dataset: { annotationIndex: String(index) }, "aria-label": `${overlayData.number}. ${overlayData.label}`, "aria-controls": detailId, "aria-expanded": "false", "aria-describedby": overlayData.description ? detailId : undefined }, [element("span", { className: "annotation-number", text: String(overlayData.number) }), element("span", { id: detailId, className: `annotation-label ${overlayTooltipClass(overlayData)}` }, markerDetailNodes(overlayData))]);
    overlayLayer.append(marker);
    const legendButton = overlayData.showLegend === false ? null : element("button", { type: "button", className: `annotation-tone-${overlayTone(overlayData)}` }, markerLegendContent(overlayData));
    const legendItem = legendButton ? element("li", { className: `annotation-tone-${overlayTone(overlayData)} annotation-type-marker` }, [legendButton]) : null;
    activationEntries.push({ id: overlayData.id, trigger: marker, legendTrigger: legendButton, legendItem });
    if (legendItem) nodes.lightboxMarkers.append(legendItem);
  });
  if (activationEntries.length) lightboxOverlayActivation = bindSingleActiveOverlay(nodes.lightbox, activationEntries);
  nodes.lightboxMarkers.hidden = !nodes.lightboxMarkers.children.length;
  nodes.lightboxCaption.textContent = caption;
  nodes.lightboxCaption.hidden = !caption;
  syncAnnotationLayer(nodes.lightboxStage, nodes.lightboxImage);
  nodes.lightbox.hidden = false;
  document.body.classList.add("overlay-open");
  setState({ lightboxOpen: true });
  nodes.lightboxClose.focus();
}

function closeLightbox() {
  if (nodes.lightbox.hidden) return;
  nodes.lightbox.hidden = true;
  lightboxOverlayActivation?.dispose();
  lightboxOverlayActivation = null;
  nodes.lightboxImage.removeAttribute("src");
  nodes.lightboxStage.querySelectorAll(".annotation-marker").forEach((node) => node.remove());
  nodes.lightboxStage.querySelectorAll(".annotation-rectangle-button").forEach((node) => node.remove());
  nodes.lightboxStage.querySelector(".annotation-layer")?.remove();
  nodes.lightboxStage.querySelector(".annotation-overlay-svg")?.remove();
  nodes.lightboxMarkers.replaceChildren();
  document.body.classList.remove("overlay-open");
  setState({ lightboxOpen: false });
  focusBeforeOverlay?.focus();
}

function setDrawer(open) {
  nodes.drawer.classList.toggle("is-open", open);
  nodes.backdrop.hidden = !open;
  nodes.drawerButton.setAttribute("aria-expanded", String(open));
  document.body.classList.toggle("drawer-open", open);
  setState({ drawerOpen: open });
  if (open) {
    focusBeforeOverlay = document.activeElement;
    nodes.drawerClose.focus();
  } else if (focusBeforeOverlay === nodes.drawerButton) nodes.drawerButton.focus();
}

function setSearch(open) {
  nodes.searchPanel.hidden = !open;
  nodes.searchButton.setAttribute("aria-expanded", String(open));
  document.body.classList.toggle("search-open", open);
  if (open) {
    focusBeforeOverlay = document.activeElement;
    nodes.searchInput.value = "";
    clear(nodes.searchResults);
    requestAnimationFrame(() => nodes.searchInput.focus());
  } else focusBeforeOverlay?.focus();
}

function markActive(sectionId) {
  setState({ section: sectionId, sectionId });
  nodes.toc.querySelectorAll("a").forEach((link) => link.classList.toggle("active", link.dataset.sectionId === sectionId));
}

function observeSections() {
  sectionObserver?.disconnect();
  sectionObserver = new IntersectionObserver((entries) => {
    const visible = entries.filter((entry) => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
    if (visible) markActive(visible.target.id);
  }, { rootMargin: "-16% 0px -68%", threshold: [0, 0.25, 0.6] });
  nodes.content.querySelectorAll(".manual-section").forEach((section) => sectionObserver.observe(section));
}

function populateLanguages() {
  clear(nodes.language);
  const labels = { es: "ES", en: "EN", de: "DE", fr: "FR" };
  const languages = libraryData?.library.languages ?? manualData?.manual.languages ?? [];
  languages.forEach((language) => nodes.language.append(element("option", { value: language, text: labels[language] ?? language.toUpperCase(), selected: language === getState().language })));
}

function collectionBreadcrumbs(path, videoItem = null) {
  const result = [{ label: ui("library.title"), route: { view: "library" } }];
  path.forEach((collectionId, index) => {
    const collection = libraryData.collections[collectionId];
    result.push({ label: ui(collection.titleKey), route: index === path.length - 1 && !videoItem ? null : { view: "collection", collectionId } });
  });
  if (videoItem) result.push({ label: ui(videoItem.titleKey), route: null });
  return result;
}

function openItem(item, containerId = getState().collectionId) {
  if (item.type === "manual") navigation.open({ view: "manual", manualId: item.manualId });
  else if (item.type === "collection") navigation.open({ view: "collection", collectionId: item.collectionId });
  else if (item.type === "video") navigation.open({ view: "video", videoId: item.id, collectionId: containerId });
}

function libraryContext() {
  return { t: libraryTranslator, assetUrl: libraryAssetUrl, devMode: options.devMode, apiBaseUrl: options.apiBaseUrl, publicApiBaseUrl: options.publicApiBaseUrl, openItem, openSearch: () => setSearch(true), openRoute: (route) => navigation.open(route) };
}

async function ensureLibraryData() {
  if (libraryData) return libraryData;
  previewTrace("catalogs:load:start", { scope: "library" });
  libraryData = await loadLibraryPackage(requestedLanguage);
  const language = libraryData.language;
  setState({ library: libraryData.library, language, devMode: options.devMode });
  libraryTranslator = createTranslator(libraryData.catalogs, language, libraryData.library.defaultLanguage, options.devMode);
  librarySearchEntries = buildLibrarySearchIndex(libraryData.library, libraryData.collections, libraryTranslator);
  return libraryData;
}

function configureShell(route, title) {
  const manual = route.view === "manual";
  nodes.content.className = manual ? "manual-content" : "manual-content application-content";
  nodes.drawer.hidden = !manual;
  nodes.drawerButton.hidden = !manual;
  nodes.back.hidden = route.view === "library";
  nodes.title.textContent = title;
  nodes.back.setAttribute("aria-label", ui("ui.back"));
  nodes.searchButton.setAttribute("aria-label", ui("ui.search"));
  nodes.drawerButton.setAttribute("aria-label", ui("ui.index"));
  nodes.language.setAttribute("aria-label", ui("ui.language"));
  nodes.searchClose.textContent = ui("ui.close_search");
  nodes.searchInput.placeholder = ui("ui.search");
  document.title = title;
  document.documentElement.lang = getState().language;
  setDrawer(false);
  setSearch(false);
  window.scrollTo({ top: 0, behavior: "auto" });
}

async function renderLibraryRoute(route) {
  await ensureLibraryData();
  const library = libraryData.library;
  configureShell(route, ui(library.metadata.titleKey));
  if (route.view === "library") {
    renderLibraryPage(nodes.content, {
      title: ui(library.metadata.titleKey), subtitle: ui(library.metadata.subtitleKey), items: library.items,
      gridTitle: ui("library.all_manuals"), isRoot: true, breadcrumbs: [],
    }, libraryContext());
    return;
  }
  if (route.view === "collection") {
    const collection = libraryData.collections[route.collectionId];
    if (!collection) throw new LibraryLoadError("COLLECTION_MISSING", `Colección no encontrada: ${route.collectionId}`);
    const path = findCollectionPath(library, libraryData.collections, route.collectionId) ?? [route.collectionId];
    configureShell(route, ui(collection.titleKey));
    renderLibraryPage(nodes.content, {
      title: ui(collection.titleKey), subtitle: collection.subtitleKey ? ui(collection.subtitleKey) : "", items: collection.items,
      gridTitle: ui("library.all_manuals"), isRoot: false, breadcrumbs: collectionBreadcrumbs(path),
    }, libraryContext());
    return;
  }
  const found = findVideo(library, libraryData.collections, route.videoId, route.collectionId);
  if (!found) throw new LibraryLoadError("VIDEO_MISSING", `Vídeo no encontrado: ${route.videoId}`);
  configureShell(route, ui(found.item.titleKey));
  renderVideoPage(nodes.content, { item: found.item, breadcrumbs: collectionBreadcrumbs(found.path, found.item) }, libraryContext());
}

async function renderManualRoute(route, restore = null) {
  previewTrace("manual:fetch:start", { manualId: route.manualId, requestedLanguage });
  manualData = await loadManualPackage(route.manualId, requestedLanguage);
  previewTrace("manual:fetch:ok", { manualId: manualData.manual.id, language: manualData.language, root: manualData.root.href });
  const language = manualData.language;
  if (language !== getState().language) setState({ language });
  manualTranslator = createTranslator(manualData.catalogs, language, manualData.manual.defaultLanguage, options.devMode);
  manualOptionalTranslator = createOptionalTranslator(manualData.catalogs, language, manualData.manual.defaultLanguage);
  previewTrace("catalogs:load:ok", { languages: Object.keys(manualData.catalogs), activeLanguage: language });
  localizedAssets = await resolveLocalizedAssets(manualData.manual, manualData.root, manualData.languageChain, { devMode: options.devMode });
  const title = manualTranslator(manualData.manual.metadata.titleKey);
  configureShell(route, title);
  previewTrace("renderer:mount:start", { sections: manualData.manual.sections.length });
  renderManual(nodes.content, nodes.toc, manualData.manual, {
    t: manualTranslator, optionalT: manualOptionalTranslator, assetUrl: manualAssetUrl, openLightbox, devMode: options.devMode, printMode: options.printMode, apiBaseUrl: options.apiBaseUrl, publicApiBaseUrl: options.publicApiBaseUrl,
    ui: {
      videoUnavailable: ui("ui.video_unavailable"), videoConnectionUnavailable: ui("ui.video_connection_unavailable"), videoPlay: ui("ui.video_play"), videoUnsupported: ui("ui.video_unsupported"),
      assetUnavailable: ui("ui.asset_unavailable"),
      annotationMode: ui("ui.annotation_mode"), annotationInstruction: ui("ui.annotation_instruction"), copyJson: ui("ui.copy_json"),
      copied: ui("ui.copied"), copyFallback: ui("ui.copy_fallback"),
    },
  });
  previewTrace("renderer:mount:ok", { contentNodes: nodes.content.children.length });
  if (options.printMode) {
    nodes.app.dataset.printRendered = "true";
    nodes.app.dataset.printReady = "false";
  }
  manualSearchEntries = buildSearchIndex(manualData.manual, manualData.catalogs[language], manualTranslator);
  observeSections();
  const requestedSection = restore?.sectionId ?? hashSection() ?? getState().sectionId ?? manualData.manual.sections[0].id;
  await new Promise((resolve) => requestAnimationFrame(() => {
    const target = manualData.manual.sections.some((section) => section.id === requestedSection) ? requestedSection : manualData.manual.sections[0].id;
    if (!navigateHash(target, false) && restore?.scrollY) window.scrollTo({ top: restore.scrollY, behavior: "auto" });
    else if (restore?.scrollY) window.scrollTo({ top: Math.max(0, restore.scrollY), behavior: "auto" });
    markActive(target);
    document.dispatchEvent(new CustomEvent("omnimanual:rendered", { detail: { manualId: manualData.manual.id, language: manualData.language, sectionId: target } }));
    resolve();
  }));
}

async function renderRoute(route) {
  sectionObserver?.disconnect();
  const previous = getState();
  const keepSection = route.view === "manual" && previous.view === "manual" && previous.manualId === route.manualId;
  setState({
    view: route.view, manualId: route.manualId ?? null, collectionId: route.collectionId ?? null,
    videoId: route.videoId ?? null, manual: route.view === "manual" ? getState().manual : null,
    sectionId: keepSection ? previous.sectionId : null, section: keepSection ? previous.section : null,
  });
  if (route.view === "manual") await renderManualRoute(route);
  else await renderLibraryRoute(route);
  setState({ manual: route.view === "manual" ? manualData.manual : null, manifest: route.view === "manual" ? manualData.manifest : null });
  populateLanguages();
  nodes.app.setAttribute("aria-busy", "false");
}

function renderSearchResults(query) {
  clear(nodes.searchResults);
  if (!query.trim()) return;
  if (getState().view === "manual") {
    const results = searchIndex(manualSearchEntries, query);
    if (!results.length) nodes.searchResults.append(element("p", { className: "empty-results", text: ui("ui.no_results") }));
    results.forEach((result) => {
      const button = element("button", { type: "button", className: "search-result" }, [element("strong", { text: result.title }), element("span", { text: result.excerpt })]);
      button.addEventListener("click", () => { setSearch(false); navigateHash(result.sectionId); markActive(result.sectionId); });
      nodes.searchResults.append(button);
    });
    return;
  }
  const results = searchLibrary(librarySearchEntries, query);
  if (!results.length) nodes.searchResults.append(element("p", { className: "empty-results", text: ui("ui.no_results") }));
  results.forEach((result) => {
    const button = element("button", { type: "button", className: "search-result" }, [
      element("span", { className: "search-result-type", text: ui(`ui.types.${result.type}`) }),
      element("strong", { text: result.title }), result.secondary ? element("span", { text: result.secondary }) : null,
    ]);
    button.addEventListener("click", () => { setSearch(false); openItem(result.item, result.containerId); });
    nodes.searchResults.append(button);
  });
}

async function changeLanguage(language) {
  requestedLanguage = language;
  if (libraryData) {
    await loadLibraryLanguage(libraryData, language);
    libraryTranslator = createTranslator(libraryData.catalogs, language, libraryData.library.defaultLanguage, options.devMode);
    librarySearchEntries = buildLibrarySearchIndex(libraryData.library, libraryData.collections, libraryTranslator);
  }
  setState({ language });
  if (getState().view === "manual" && manualData) await loadLanguage(manualData.root, manualData.manual, language, manualData.catalogs);
  navigation.replaceUrl();
  await renderRoute(navigation.getState().current);
}

function postBridgeMessage(message) {
  window.OmniManualBridge?.postMessage?.(JSON.stringify(message));
}

function reportBridgeState(state, detail = {}) {
  postBridgeMessage({ type: "state", state, detail });
}

function postBridgeActionResult(requestId, command, result) {
  postBridgeMessage({ type: "actionResult", requestId, result: { command, ...result } });
}

async function handleBridgeRequest(requestId, command, payload = {}) {
  try {
    if (command === "openSearch") {
      setSearch(true);
      postBridgeActionResult(requestId, command, { ok: true, detail: getState() });
      return;
    }
    if (command === "openTableOfContents") {
      if (getState().view === "manual") setDrawer(true);
      postBridgeActionResult(requestId, command, { ok: true, detail: getState() });
      return;
    }
    if (command === "setLocale") {
      const language = payload?.language;
      if (typeof language !== "string" || !language) throw new Error("Idioma no válido para setLocale");
      await changeLanguage(language);
      postBridgeActionResult(requestId, command, { ok: true, detail: { language: getState().language } });
      return;
    }
    postBridgeActionResult(requestId, command, { ok: false, code: "unknown_command", message: `Acción no soportada: ${command}`, detail: getState() });
  } catch (error) {
    postBridgeActionResult(requestId, command, { ok: false, code: "runtime_error", message: error instanceof Error ? error.message : String(error), detail: getState() });
  }
}

function showError(error) {
  console.error("[Omni Studio]", error);
  window.__omniPreviewReportError?.("runtime-bootstrap", error);
  const known = error instanceof ManualLoadError || error instanceof LibraryLoadError;
  renderFatal(nodes.content, "No se pudo abrir la documentación", known ? error.message : "Se produjo un error inesperado al cargar el contenido.");
  nodes.app.setAttribute("aria-busy", "false");
  reportBridgeState("failed", { message: known ? error.message : "Se produjo un error inesperado al cargar el contenido.", url: window.location.href });
}

function bindEvents() {
  nodes.back.addEventListener("click", () => navigation.back());
  nodes.searchButton.addEventListener("click", () => setSearch(nodes.searchPanel.hidden));
  nodes.searchClose.addEventListener("click", () => setSearch(false));
  nodes.searchInput.addEventListener("input", () => renderSearchResults(nodes.searchInput.value));
  nodes.searchForm.addEventListener("submit", (event) => event.preventDefault());
  nodes.drawerButton.addEventListener("click", () => setDrawer(true));
  nodes.drawerClose.addEventListener("click", () => setDrawer(false));
  nodes.backdrop.addEventListener("click", () => setDrawer(false));
  nodes.lightboxClose.addEventListener("click", closeLightbox);
  nodes.lightbox.addEventListener("click", (event) => { if (event.target === nodes.lightbox) closeLightbox(); });
  nodes.toc.addEventListener("click", (event) => {
    const link = event.target.closest("a[data-section-id]");
    if (!link) return;
    event.preventDefault();
    navigateHash(link.dataset.sectionId);
    markActive(link.dataset.sectionId);
    setDrawer(false);
  });
  nodes.language.addEventListener("change", () => changeLanguage(nodes.language.value).catch(showError));
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    if (getState().lightboxOpen) closeLightbox();
    else if (getState().drawerOpen) setDrawer(false);
    else if (!nodes.searchPanel.hidden) setSearch(false);
  });
  window.addEventListener("hashchange", () => { if (getState().view === "manual" && hashSection()) navigateHash(hashSection(), false); });
}

function nextFrame() {
  return new Promise((resolve) => requestAnimationFrame(resolve));
}

function imageDiagnostics(image, reason) {
  return {
    src: image.currentSrc || image.src || image.dataset.assetSrc || "",
    sectionId: image.dataset.sectionId || image.closest(".manual-section")?.dataset.sectionId || "",
    blockIndex: image.dataset.blockIndex || "",
    reason,
    naturalWidth: image.naturalWidth,
    naturalHeight: image.naturalHeight,
    complete: image.complete,
  };
}

async function waitForImage(image) {
  image.loading = "eager";
  image.decoding = "sync";
  if (!image.complete) {
    await new Promise((resolve) => {
      const done = () => resolve();
      image.addEventListener("load", done, { once: true });
      image.addEventListener("error", done, { once: true });
      setTimeout(done, 8000);
    });
  }
  if (typeof image.decode === "function" && image.complete && image.naturalWidth > 0) {
    try { await image.decode(); } catch { return imageDiagnostics(image, "decode() rechazó la imagen"); }
  }
  if (!image.complete) return imageDiagnostics(image, "la imagen no terminó de cargar");
  if (image.naturalWidth <= 0 || image.naturalHeight <= 0) return imageDiagnostics(image, "naturalWidth/naturalHeight es 0");
  return null;
}

function rectSnapshot(node) {
  const rect = node?.getBoundingClientRect?.();
  return rect ? {
    left: Math.round(rect.left * 100) / 100,
    top: Math.round(rect.top * 100) / 100,
    right: Math.round(rect.right * 100) / 100,
    bottom: Math.round(rect.bottom * 100) / 100,
    width: Math.round(rect.width * 100) / 100,
    height: Math.round(rect.height * 100) / 100,
  } : null;
}

function rectDelta(a, b) {
  return {
    left: Math.abs((a?.left ?? 0) - (b?.left ?? 0)),
    top: Math.abs((a?.top ?? 0) - (b?.top ?? 0)),
    width: Math.abs((a?.width ?? 0) - (b?.width ?? 0)),
    height: Math.abs((a?.height ?? 0) - (b?.height ?? 0)),
  };
}

function rectsMatch(a, b, tolerance = 1.5) {
  if (!a || !b) return false;
  return Object.values(rectDelta(a, b)).every((value) => value <= tolerance);
}

function effectiveOpacity(node) {
  let current = node;
  let opacity = 1;
  while (current && current.nodeType === 1) {
    const style = getComputedStyle(current);
    opacity *= Number(style.opacity || 1);
    current = current.parentElement;
  }
  return opacity;
}

function imageVisibilityDiagnostics(image, contentWidth) {
  const rect = rectSnapshot(image);
  const style = getComputedStyle(image);
  if (!rect?.width || !rect.height) return imageDiagnostics(image, "la imagen cargó pero su rectángulo renderizado es 0");
  if (style.display === "none") return imageDiagnostics(image, "display:none");
  if (style.visibility === "hidden" || style.visibility === "collapse") return imageDiagnostics(image, `visibility:${style.visibility}`);
  if (effectiveOpacity(image) <= 0.01) return imageDiagnostics(image, "opacity efectiva 0");
  if (rect.right < 0 || rect.left > contentWidth + 1) return imageDiagnostics(image, "la imagen queda fuera del ancho exportable");
  return null;
}

function validateAnnotationGeometry(stage) {
  const surface = stage.querySelector(".annotation-surface") ?? stage;
  const image = surface.querySelector("img");
  const svg = surface.querySelector(".annotation-overlay-svg");
  const layer = surface.querySelector(".annotation-layer");
  if (!image || !svg || !layer) return null;
  const surfaceRect = rectSnapshot(surface);
  const imageRect = rectSnapshot(image);
  const svgRect = rectSnapshot(svg);
  const markerLayerRect = rectSnapshot(layer);
  const style = getComputedStyle(image);
  const valid = rectsMatch(surfaceRect, imageRect) && rectsMatch(surfaceRect, svgRect) && rectsMatch(surfaceRect, markerLayerRect);
  return valid ? null : {
    sectionId: image.dataset.sectionId || stage.closest(".manual-section")?.dataset.sectionId || "",
    blockIndex: image.dataset.blockIndex || "",
    src: image.currentSrc || image.src || image.dataset.assetSrc || "",
    naturalWidth: image.naturalWidth,
    naturalHeight: image.naturalHeight,
    objectFit: style.objectFit,
    objectPosition: style.objectPosition,
    surfaceRect,
    imageRect,
    svgRect,
    markerLayerRect,
    delta: { image: rectDelta(surfaceRect, imageRect), svg: rectDelta(surfaceRect, svgRect), markerLayer: rectDelta(surfaceRect, markerLayerRect) },
    reason: "surface, imagen, SVG y capa de markers no comparten el mismo rectángulo",
  };
}

function printContentHeight() {
  const appRect = nodes.app.getBoundingClientRect();
  const contentRect = nodes.content.getBoundingClientRect();
  return Math.ceil(Math.max(
    document.documentElement.scrollHeight,
    document.body.scrollHeight,
    nodes.app.scrollHeight,
    nodes.content.scrollHeight + Math.max(0, contentRect.top),
    appRect.bottom,
    contentRect.bottom,
  ));
}

async function waitForStableLayout() {
  let previous = -1;
  let stable = 0;
  let current = 0;
  for (let index = 0; index < 12; index += 1) {
    await nextFrame();
    current = printContentHeight();
    stable = current === previous ? stable + 1 : 0;
    if (stable >= 2) return { height: current, stable: true };
    previous = current;
  }
  return { height: current || printContentHeight(), stable: false };
}

function setPrintLayout(layout, contentWidth) {
  document.documentElement.classList.add("omni-print-mode");
  document.body.classList.add("omni-print-mode");
  document.documentElement.classList.toggle("omni-print-continuous", layout === "continuous");
  document.body.classList.toggle("omni-print-continuous", layout === "continuous");
  document.documentElement.classList.toggle("omni-print-paged", layout !== "continuous");
  document.body.classList.toggle("omni-print-paged", layout !== "continuous");
  if (layout === "continuous" && Number.isFinite(contentWidth) && contentWidth > 0) {
    document.documentElement.style.setProperty("--print-continuous-width", `${contentWidth}px`);
  }
}

function overflowDiagnostics() {
  return Array.from(nodes.content.querySelectorAll("*")).map((node) => {
    if (node.classList?.contains("sr-only") || node.closest?.(".sr-only, .visually-hidden")) return null;
    const overflow = node.scrollWidth - node.clientWidth;
    if (overflow <= 32) return null;
    return {
      tag: node.tagName.toLowerCase(),
      className: node.className || "",
      sectionId: node.closest(".manual-section")?.dataset.sectionId || "",
      scrollWidth: node.scrollWidth,
      clientWidth: node.clientWidth,
      overflow,
    };
  }).filter(Boolean).slice(0, 20);
}

async function prepareForPrint(request = {}) {
  const layout = request.layout === "continuous" ? "continuous" : options.printLayout === "continuous" ? "continuous" : "paged";
  const contentWidth = Number.isFinite(Number(request.contentWidth)) && Number(request.contentWidth) > 0 ? Number(request.contentWidth) : window.innerWidth;
  setPrintLayout(layout, contentWidth);
  nodes.app.setAttribute("aria-busy", "true");
  const state = getState();
  const images = Array.from(nodes.content.querySelectorAll("img"));
  const failedImages = [];
  for (const image of images) {
    const failure = await waitForImage(image);
    if (failure) failedImages.push(failure);
  }
  await (document.fonts?.ready ?? Promise.resolve());
  const stability = await waitForStableLayout();
  await nextFrame();
  const hiddenImages = images.map((image) => imageVisibilityDiagnostics(image, contentWidth)).filter(Boolean);
  const geometryFailures = Array.from(nodes.content.querySelectorAll(".annotation-stage")).map(validateAnnotationGeometry).filter(Boolean);
  const fallbackFailures = Array.from(nodes.content.querySelectorAll(".asset-fallback")).map((node) => ({
    sectionId: node.closest(".manual-section")?.dataset.sectionId || "",
    blockIndex: "",
    src: "",
    reason: node.textContent || "asset fallback presente durante la preparación de impresión",
  }));
  const overflow = layout === "continuous" ? overflowDiagnostics() : [];
  const annotatedTotal = nodes.content.querySelectorAll(".annotation-stage .annotation-overlay-svg").length;
  const report = {
    ready: failedImages.length === 0 && hiddenImages.length === 0 && geometryFailures.length === 0 && fallbackFailures.length === 0 && overflow.length === 0 && stability.stable,
    layout,
    manualId: state.manual?.id ?? state.manualId ?? null,
    language: state.language,
    contentWidthCssPx: contentWidth,
    contentHeightCssPx: stability.height,
    stable: stability.stable,
    images: { expected: images.length, total: images.length, loaded: images.length - failedImages.length, visible: images.length - failedImages.length - hiddenImages.length, failed: [...failedImages, ...hiddenImages] },
    annotatedImages: { total: annotatedTotal, checked: annotatedTotal, failed: geometryFailures },
    geometry: { checked: annotatedTotal, failed: geometryFailures },
    overflow,
    fallbacks: fallbackFailures,
  };
  nodes.app.dataset.printReady = String(report.ready);
  nodes.app.setAttribute("aria-busy", "false");
  if (report.ready) document.dispatchEvent(new CustomEvent("omnimanual:print-ready", { detail: report }));
  return report;
}

async function bootstrap() {
  previewTrace("runtime-bootstrap:start", { requestedLanguage, route: options.route });
  if (options.printMode) setPrintLayout(options.printLayout, window.innerWidth);
  if (options.devMode) {
    document.documentElement.dataset.viewport = `${window.innerWidth}x${window.innerHeight}`;
    console.info(`[Omni Studio dev] viewport=${document.documentElement.dataset.viewport}`);
  }
  setState({ devMode: options.devMode });
  navigation = createNavigationController({
    initial: options.route,
    initialUrl: window.location.href,
    onChange: (route) => renderRoute(route).catch(showError),
    urlFor: (route) => routeUrl(route, getState().language, options.devMode),
  });
  bindEvents();
  await renderRoute(options.route);
  window.OmniManual = Object.freeze({
    load: async (manualId, languageCode = getState().language) => { if (languageCode !== getState().language) await changeLanguage(languageCode); return navigation.open({ view: "manual", manualId }); },
    openLibrary: () => navigation.open({ view: "library" }),
    openCollection: (collectionId) => isValidId(collectionId) && navigation.open({ view: "collection", collectionId }),
    openManual: (manualId) => isValidId(manualId) && navigation.open({ view: "manual", manualId }),
    openVideo: (videoId) => isValidId(videoId) && navigation.open({ view: "video", videoId }),
    openSearch: () => setSearch(true),
    openTableOfContents: () => { if (getState().view === "manual") setDrawer(true); },
    handleBridgeRequest,
    back: () => navigation.back(), setLanguage: changeLanguage, setLocale: changeLanguage, navigateTo: navigateHash,
    getLoadedManualIdentity: () => {
      const state = getState();
      return { id: state.manual?.id ?? state.manualId ?? null, language: state.language ?? null, titleKey: state.manual?.metadata?.titleKey ?? null, view: state.view };
    },
    prepareForPrint,
    reloadCurrent: async (reloadOptions = {}) => {
      const current = getState();
      if (current.view !== "manual" || !current.manualId) return current;
      const snapshot = { sectionId: reloadOptions.sectionId ?? current.sectionId, scrollY: Number.isFinite(reloadOptions.scrollY) ? reloadOptions.scrollY : window.scrollY };
      nodes.app.setAttribute("aria-busy", "true");
      try {
        await renderManualRoute({ view: "manual", manualId: current.manualId }, snapshot);
        setState({ manual: manualData.manual, manifest: manualData.manifest });
        nodes.app.setAttribute("aria-busy", "false");
        return getState();
      } catch (error) { nodes.app.setAttribute("aria-busy", "false"); throw error; }
    },
    getState,
  });
  previewTrace("runtime-bootstrap:ready", { view: getState().view, manualId: getState().manualId });
  reportBridgeState("ready", { view: getState().view, manualId: getState().manualId, language: getState().language, url: window.location.href });
}

bootstrap().catch(showError);
