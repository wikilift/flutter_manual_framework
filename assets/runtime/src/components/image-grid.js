import { element } from "../dom.js";
import { mediaFigure } from "./shared.js";

export function renderImageGrid(block, context) {
  return element("div", { className: "image-grid technical-width" }, block.images.map((image) => mediaFigure(image, context)));
}
