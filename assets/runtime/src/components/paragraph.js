import { element } from "../dom.js";

export function normalizeHighlights(highlights = []) {
  const unique = new Map();
  highlights.forEach((item, index) => {
    const value = typeof item === "string" ? { text: item, important: false } : item;
    if (!value || typeof value.text !== "string" || !value.text) return;
    const key = value.text.toLocaleLowerCase();
    const current = unique.get(key);
    unique.set(key, { text: value.text, important: value.important === true || current?.important === true, index: current?.index ?? index });
  });
  return [...unique.values()].sort((a, b) => b.text.length - a.text.length || a.index - b.index);
}

export function appendHighlightedText(node, text, highlights = []) {
  const terms = normalizeHighlights(highlights);
  if (!terms.length) {
    node.textContent = text;
    return;
  }
  const escaped = terms.map((term) => term.text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
  const matcher = new RegExp(`(${escaped.join("|")})`, "gi");
  text.split(matcher).filter(Boolean).forEach((part) => {
    const match = terms.find((term) => term.text.toLocaleLowerCase() === part.toLocaleLowerCase());
    node.append(match
      ? element("strong", { className: `manual-highlight${match.important ? " manual-highlight--important" : ""}`, text: part }) : document.createTextNode(part));
  });
}

export function renderParagraph(block, context) {
  const classes = ["paragraph"];
  if (block.emphasis === true) classes.push("emphasis");
  if (block.important === true) classes.push("manual-paragraph--important");
  const paragraph = element("p", { className: classes.join(" ") });
  appendHighlightedText(paragraph, context.t(block.textKey), block.highlights);
  return paragraph;
}
