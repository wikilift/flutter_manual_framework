import { element } from "../dom.js";
import { appendHighlightedText } from "./paragraph.js";

const WARNING_TONES = new Set(["blue", "green", "amber", "red", "gray", "purple"]);

function warningTone(block) {
  return WARNING_TONES.has(block.tone) ? block.tone : "amber";
}

export function renderWarning(block, context) {
  const text = element("p");
  appendHighlightedText(text, context.t(block.textKey), block.highlights);
  return element("aside", { className: `callout warning warning-tone-${warningTone(block)}`, role: "note" }, [
    element("h3", { text: context.t(block.titleKey) }),
    text,
  ]);
}
