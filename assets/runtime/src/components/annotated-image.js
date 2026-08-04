import { mediaFigure } from "./shared.js";

export function renderAnnotatedImage(block, context) {
  return mediaFigure(block, context, "annotated-image technical-width");
}
