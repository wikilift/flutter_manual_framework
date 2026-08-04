import { element } from "../dom.js";
import { mediaFigure, optionalTranslationText } from "./shared.js";

export function renderCover(block, context) {
  const subtitle = optionalTranslationText(context, block.subtitleKey);
  const date = optionalTranslationText(context, block.dateKey);
  const footer = optionalTranslationText(context, block.footerKey);
  const copy = element("div", { className: "cover-copy" }, [
    element("h1", { text: context.t(block.titleKey) }),
    subtitle ? element("p", { className: "cover-subtitle", text: subtitle }) : null,
    date ? element("p", { className: "cover-date", text: date }) : null,
    footer ? element("p", { className: "cover-footer", text: footer }) : null,
  ]);
  const children = [copy, block.image ? mediaFigure(block.image, context, "media-figure cover-image") : null];
  return element("div", { className: "cover-layout" }, children);
}
