import { element } from "../dom.js";

export function renderNote(block, context) {
  return element("aside", { className: "callout note" }, [
    element("h3", { text: context.t(block.titleKey) }),
    element("p", { text: context.t(block.textKey) }),
  ]);
}
