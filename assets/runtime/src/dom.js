export function element(tagName, options = {}, children = []) {
  const node = document.createElement(tagName);
  for (const [key, value] of Object.entries(options)) {
    if (value === undefined || value === null) continue;
    if (key === "className") node.className = value;
    else if (key === "text") node.textContent = value;
    else if (key === "dataset") Object.assign(node.dataset, value);
    else if (key in node && key !== "style") node[key] = value;
    else node.setAttribute(key, String(value));
  }
  node.append(...children.filter(Boolean));
  return node;
}

export function clear(node) {
  node.replaceChildren();
}

export function technicalError(message) {
  return element("aside", { className: "technical-error", text: message, role: "alert" });
}

export function renderFatal(container, title, detail) {
  clear(container);
  container.append(element("section", { className: "fatal-error" }, [
    element("p", { className: "error-code", text: "OMNIMANUAL" }),
    element("h1", { text: title }),
    element("p", { text: detail }),
  ]));
}
