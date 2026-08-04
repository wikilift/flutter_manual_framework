import { element } from "../dom.js";
import { optionalTranslationText } from "./shared.js";

const alignClass = (value) => ["center", "right"].includes(value) ? `align-${value}` : "align-left";

function safeColor(value) {
  return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? value : null;
}

function cell(tagName, text, align, options = {}) {
  const classes = [alignClass(align), options.bold ? "cell-bold" : ""].filter(Boolean).join(" ");
  const background = safeColor(options.backgroundColor);
  const textColor = safeColor(options.textColor);
  const style = [background ? `background-color:${background}` : "", textColor ? `color:${textColor}` : ""].filter(Boolean).join(";");
  return element(tagName, { className: classes, style: style || undefined, text });
}

export function renderTable(block, context) {
  const figure = element("figure", { className: `manual-table${block.borders === false ? " no-borders" : ""}` });
  const caption = optionalTranslationText(context, block.captionKey);
  if (caption) figure.append(element("figcaption", { text: caption }));
  const table = element("table");
  const hasHeader = block.header !== false && (block.columns ?? []).some((column) => column.headerKey);
  if (hasHeader) {
    table.append(element("thead", {}, [
      element("tr", {}, (block.columns ?? []).map((column) => cell("th", column.headerKey ? context.t(column.headerKey) : "", column.align))),
    ]));
  }
  const body = element("tbody");
  (block.rows ?? []).forEach((row) => {
    body.append(element("tr", {}, (block.columns ?? []).map((column, index) => {
      const current = row.cells?.[index];
      return cell("td", current?.textKey ? context.t(current.textKey) : "", current?.align ?? column.align, current);
    })));
  });
  table.append(body);
  figure.append(table);
  return figure;
}
