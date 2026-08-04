import { element } from "../dom.js";
import { optionalTranslationText } from "./shared.js";

function port(symbol, name) {
  if (name === "left") return { x: symbol.x, y: symbol.y + symbol.height / 2 };
  if (name === "right") return { x: symbol.x + symbol.width, y: symbol.y + symbol.height / 2 };
  if (name === "top") return { x: symbol.x + symbol.width / 2, y: symbol.y };
  return { x: symbol.x + symbol.width / 2, y: symbol.y + symbol.height };
}

function wirePath(wire, symbols) {
  const from = symbols.get(wire.from?.symbolId);
  const to = symbols.get(wire.to?.symbolId);
  if (!from || !to) return "";
  const points = [port(from, wire.from.port), ...(wire.waypoints ?? []), port(to, wire.to.port)];
  if (points.length === 2) {
    const [start, end] = points;
    const midX = (start.x + end.x) / 2;
    points.splice(1, 0, { x: midX, y: start.y }, { x: midX, y: end.y });
  }
  return points.map((point, index) => `${index ? "L" : "M"} ${point.x} ${point.y}`).join(" ");
}

function renderSymbol(svg, symbol, context) {
  const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
  group.setAttribute("class", `electrical-symbol electrical-symbol-${symbol.kind}`);
  const box = document.createElementNS("http://www.w3.org/2000/svg", "rect");
  box.setAttribute("x", symbol.x);
  box.setAttribute("y", symbol.y);
  box.setAttribute("width", symbol.width);
  box.setAttribute("height", symbol.height);
  box.setAttribute("rx", "6");
  group.append(box);
  if (symbol.kind === "ground") {
    const line = document.createElementNS("http://www.w3.org/2000/svg", "path");
    line.setAttribute("d", `M ${symbol.x + symbol.width / 2} ${symbol.y} V ${symbol.y + symbol.height * .45} M ${symbol.x + symbol.width * .25} ${symbol.y + symbol.height * .55} H ${symbol.x + symbol.width * .75} M ${symbol.x + symbol.width * .35} ${symbol.y + symbol.height * .68} H ${symbol.x + symbol.width * .65} M ${symbol.x + symbol.width * .44} ${symbol.y + symbol.height * .8} H ${symbol.x + symbol.width * .56}`);
    group.append(line);
  }
  const label = symbol.labelKey ? context.t(symbol.labelKey) : symbol.kind;
  const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
  text.setAttribute("x", symbol.x + symbol.width / 2);
  text.setAttribute("y", symbol.y + symbol.height / 2);
  text.setAttribute("text-anchor", "middle");
  text.setAttribute("dominant-baseline", "middle");
  text.textContent = label && label !== symbol.labelKey ? label : symbol.kind;
  group.append(text);
  svg.append(group);
}

export function renderElectricalSchematic(block, context) {
  const figure = element("figure", { className: "electrical-schematic technical-width" });
  const title = optionalTranslationText(context, block.titleKey);
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", `0 0 ${block.viewport.width} ${block.viewport.height}`);
  svg.setAttribute("role", "img");
  svg.setAttribute("aria-label", context.t(block.ariaLabelKey));
  const symbols = new Map((block.symbols ?? []).map((symbol) => [symbol.id, symbol]));
  (block.wires ?? []).forEach((wire) => {
    const path = wirePath(wire, symbols);
    if (!path) return;
    const node = document.createElementNS("http://www.w3.org/2000/svg", "path");
    node.setAttribute("class", "electrical-wire");
    node.setAttribute("d", path);
    svg.append(node);
  });
  (block.symbols ?? []).forEach((symbol) => renderSymbol(svg, symbol, context));
  (block.texts ?? []).forEach((item) => {
    const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
    text.setAttribute("x", item.x);
    text.setAttribute("y", item.y);
    text.textContent = context.t(item.textKey);
    svg.append(text);
  });
  figure.append(svg);
  if (title) figure.append(element("figcaption", { text: title }));
  return figure;
}
