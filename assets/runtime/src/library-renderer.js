import { clear, element } from "./dom.js";
import { createLibraryItemRegistry } from "./library-item-registry.js";

function breadcrumbs(items, context) {
  if (!items?.length) return null;
  const nav = element("nav", { className: "breadcrumbs", "aria-label": "Breadcrumb" });
  items.forEach((item, index) => {
    const button = element("button", { type: "button", text: item.label, disabled: index === items.length - 1 });
    if (item.route) button.addEventListener("click", () => context.openRoute(item.route));
    nav.append(button);
  });
  return nav;
}

export function renderLibraryPage(container, page, context, registry = createLibraryItemRegistry()) {
  clear(container);
  const header = element("header", { className: "library-intro" }, [
    breadcrumbs(page.breadcrumbs, context),
    element("p", { className: "library-kicker", text: "OMNITOOL · DOCUMENTATION" }),
    element("h1", { text: page.title }),
    page.subtitle ? element("p", { className: "library-subtitle", text: page.subtitle }) : null,
    page.isRoot ? element("button", { type: "button", className: "library-search-launch", text: context.t("library.search_prompt") }) : null,
  ]);
  header.querySelector(".library-search-launch")?.addEventListener("click", context.openSearch);
  const grid = element("div", { className: "library-grid" });
  page.items.forEach((item) => {
    const card = registry.render(item, context);
    if (card) grid.append(card);
  });
  container.append(element("section", { className: "library-page" }, [header, element("h2", { className: "library-grid-title", text: page.gridTitle }), grid]));
}

export function renderVideoPage(container, page, context) {
  clear(container);
  const video = element("video", { controls: true, preload: "metadata", playsInline: true, poster: page.item.poster ? context.assetUrl(page.item.poster) : undefined });
  const source = element("source", { src: context.assetUrl(page.item.src), type: "video/mp4" });
  video.append(source);
  video.append(document.createTextNode(context.t("ui.video_unsupported")));
  const fallback = element("div", { className: "video-view-fallback", hidden: true }, [
    element("span", { className: "fallback-symbol", "aria-hidden": "true" }),
    element("p", { text: context.t("ui.video_unavailable") }),
  ]);
  const showFallback = () => {
    video.hidden = true;
    fallback.hidden = false;
    if (context.devMode) console.warn(`[library] Vídeo opcional ausente: ${page.item.src}`);
  };
  video.addEventListener("error", showFallback, { once: true });
  source.addEventListener("error", showFallback, { once: true });
  container.append(element("article", { className: "video-view" }, [
    breadcrumbs(page.breadcrumbs, context),
    element("div", { className: "video-view-player" }, [video, fallback]),
    element("div", { className: "video-view-copy" }, [
      element("p", { className: "library-card-type", text: context.t("ui.types.video") }),
      element("h1", { text: context.t(page.item.titleKey) }),
      page.item.duration ? element("p", { className: "video-duration", text: page.item.duration }) : null,
      page.item.descriptionKey ? element("p", { text: context.t(page.item.descriptionKey) }) : null,
    ]),
  ]));
}
