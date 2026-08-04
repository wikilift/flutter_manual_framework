import { element } from "../dom.js";
import { mediaFigure } from "./shared.js";

export function renderScreenshotGallery(block, context) {
  return element("div", { className: "screenshot-gallery technical-width", role: "region", "aria-label": context.t(block.labelKey) },
    block.images.map((image) => mediaFigure(image, context, "media-figure screenshot")));
}
