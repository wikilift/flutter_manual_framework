import { element } from "./dom.js";

function createCard(item, context, type) {
  const title = context.t(item.titleKey);
  const subtitleKey = item.subtitleKey ?? item.descriptionKey;
  const subtitle = subtitleKey ? context.t(subtitleKey) : "";
  const media = element("div", { className: "library-card-media" });
  if (item.image || item.poster) {
    const image = element("img", { src: context.assetUrl(item.image ?? item.poster), alt: "", loading: "lazy", decoding: "async" });
    image.addEventListener("error", () => media.classList.add("media-missing"), { once: true });
    media.append(image);
  } else media.classList.add("media-missing");
  const metadata = item.duration ?? (item.badgeKey ? context.t(item.badgeKey) : "");
  const card = element("button", { type: "button", className: `library-card library-card-${type}`, "aria-label": `${context.t(`ui.types.${type}`)}: ${title}` }, [
    media,
    element("span", { className: "library-card-body" }, [
      element("span", { className: "library-card-type", text: context.t(`ui.types.${type}`) }),
      element("strong", { text: title }),
      subtitle ? element("span", { className: "library-card-subtitle", text: subtitle }) : null,
      metadata ? element("span", { className: "library-card-meta", text: metadata }) : null,
    ]),
  ]);
  card.addEventListener("click", () => context.openItem(item));
  return card;
}

export function createLibraryItemRegistry() {
  const renderers = new Map();
  const register = (type, renderer) => renderers.set(type, renderer);
  register("manual", (item, context) => createCard(item, context, "manual"));
  register("collection", (item, context) => createCard(item, context, "collection"));
  register("video", (item, context) => createCard(item, context, "video"));
  return Object.freeze({
    register,
    render(item, context) {
      const renderer = renderers.get(item.type);
      if (!renderer) {
        console.error(`[library] Tipo de item desconocido: ${item.type}`, item);
        return context.devMode ? element("p", { className: "technical-error", text: `Library item no compatible: ${item.type}` }) : null;
      }
      return renderer(item, context);
    },
    has: (type) => renderers.has(type),
  });
}
