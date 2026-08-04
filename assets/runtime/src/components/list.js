import { element } from "../dom.js";
import { appendHighlightedText } from "./paragraph.js";

export function renderList(block, context) {
  const tagName = block.style === "ordered" ? "ol" : "ul";
  const list = element(tagName, { className: `manual-list manual-list-${block.style === "ordered" ? "ordered" : "unordered"}` });
  (block.items ?? []).forEach((item) => {
    const node = element("li");
    appendHighlightedText(node, context.t(item.textKey), item.highlights);
    list.append(node);
  });
  return list;
}
