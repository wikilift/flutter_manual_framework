import { element } from "../dom.js";
import { mediaFigure, optionalTranslationText } from "./shared.js";
import { appendHighlightedText } from "./paragraph.js";

export function renderSteps(block, context) {
  const list = element("ol", { className: "steps" });
  block.items.forEach((item) => {
    const text = element("p");
    const title = optionalTranslationText(context, item.titleKey);
    appendHighlightedText(text, context.t(item.textKey), item.highlights);
    list.append(element("li", {}, [
      element("div", { className: "step-copy" }, [
        title ? element("h3", { text: title }) : null,
        text,
      ]),
      item.image ? mediaFigure(item.image, context, "media-figure step-image") : null,
    ]));
  });
  return list;
}
