import { element } from "../dom.js";

const SVG_NS = "http://www.w3.org/2000/svg";
const TONES = ["default", "primary", "muted", "success", "warning", "danger", "info"];
const PORTS = { top: [0.5, 0], right: [1, 0.5], bottom: [0.5, 1], left: [0, 0.5] };
const FLOWCHART_GRID_SIZE = 16;
const ALIGNMENT_EPSILON = .5;
const EDGE_COLORS = { neutral: "#536670", primary: "#14738c", info: "#4866aa", success: "#2d7c4b", warning: "#b56b0f", danger: "#b53b35" };
const EDGE_WIDTHS = { thin: 1.5, medium: 2.25, thick: 3.5 };
const NODE_FILLS = { default: "#eef2f4", neutral: "#f1f3f4", primary: "#dcecf4", info: "#e3e9fb", success: "#dff1e5", warning: "#fff0d8", danger: "#fae1df", white: "#ffffff" };
const NODE_STROKES = { default: "#536670", neutral: "#87959c", primary: "#14738c", info: "#4866aa", success: "#2d7c4b", warning: "#b56b0f", danger: "#b53b35" };
const svg = (tag, attributes = {}) => { const node = document.createElementNS(SVG_NS, tag); Object.entries(attributes).forEach(([name, value]) => node.setAttribute(name, String(value))); return node; };
const nodeBounds = (node) => ({ minX: node.x, minY: node.y, maxX: node.x + node.width, maxY: node.y + node.height, width: node.width, height: node.height });
const center = (node) => { const bounds = nodeBounds(node); return { x: bounds.minX + bounds.width / 2, y: bounds.minY + bounds.height / 2 }; };
const automaticPorts = (from, to) => { const a = center(from); const b = center(to); const dx = b.x - a.x; const dy = b.y - a.y; return Math.abs(dx) >= Math.abs(dy) ? (dx >= 0 ? ["right", "left"] : ["left", "right"]) : (dy >= 0 ? ["bottom", "top"] : ["top", "bottom"]); };
function polygonPoints(node) {
  const skew = Math.min(24, node.width * .16);
  if (node.shape === "decision") return [
    { x: node.x + node.width / 2, y: node.y },
    { x: node.x + node.width, y: node.y + node.height / 2 },
    { x: node.x + node.width / 2, y: node.y + node.height },
    { x: node.x, y: node.y + node.height / 2 },
  ];
  if (node.shape === "input") return [
    { x: node.x + skew, y: node.y },
    { x: node.x + node.width, y: node.y },
    { x: node.x + node.width - skew, y: node.y + node.height },
    { x: node.x, y: node.y + node.height },
  ];
  if (node.shape === "output") return [
    { x: node.x, y: node.y },
    { x: node.x + node.width - skew, y: node.y },
    { x: node.x + node.width, y: node.y + node.height },
    { x: node.x + skew, y: node.y + node.height },
  ];
  return null;
}
function polygonConnectionPoint(points, centerPoint, port, fallback) {
  const matches = [];
  points.forEach((start, index) => {
    const end = points[(index + 1) % points.length];
    if (port === "top" || port === "bottom") {
      if (near(start.x, end.x)) {
        if (near(centerPoint.x, start.x) && centerPoint.y >= Math.min(start.y, end.y) && centerPoint.y <= Math.max(start.y, end.y)) matches.push({ x: centerPoint.x, y: port === "top" ? Math.min(start.y, end.y) : Math.max(start.y, end.y) });
        return;
      }
      const t = (centerPoint.x - start.x) / (end.x - start.x);
      if (t >= -ALIGNMENT_EPSILON && t <= 1 + ALIGNMENT_EPSILON) matches.push({ x: centerPoint.x, y: start.y + (end.y - start.y) * t });
      return;
    }
    if (near(start.y, end.y)) {
      if (near(centerPoint.y, start.y) && centerPoint.x >= Math.min(start.x, end.x) && centerPoint.x <= Math.max(start.x, end.x)) matches.push({ x: port === "left" ? Math.min(start.x, end.x) : Math.max(start.x, end.x), y: centerPoint.y });
      return;
    }
    const t = (centerPoint.y - start.y) / (end.y - start.y);
    if (t >= -ALIGNMENT_EPSILON && t <= 1 + ALIGNMENT_EPSILON) matches.push({ x: start.x + (end.x - start.x) * t, y: centerPoint.y });
  });
  const directional = matches.filter((point) => port === "top" ? point.y <= centerPoint.y + ALIGNMENT_EPSILON : port === "bottom" ? point.y >= centerPoint.y - ALIGNMENT_EPSILON : port === "left" ? point.x <= centerPoint.x + ALIGNMENT_EPSILON : point.x >= centerPoint.x - ALIGNMENT_EPSILON);
  if (!directional.length) return fallback;
  if (port === "top") return directional.reduce((best, point) => point.y < best.y ? point : best);
  if (port === "bottom") return directional.reduce((best, point) => point.y > best.y ? point : best);
  if (port === "left") return directional.reduce((best, point) => point.x < best.x ? point : best);
  return directional.reduce((best, point) => point.x > best.x ? point : best);
}
function portPoint(node, port) {
  const [rx, ry] = PORTS[port] ?? PORTS.right; const c = center(node);
  const fallback = { x: node.x + node.width * rx, y: node.y + node.height * ry };
  if (node.shape === "connector") { const radius = Math.min(node.width, node.height) / 2; return { x: c.x + (port === "right" ? radius : port === "left" ? -radius : 0), y: c.y + (port === "bottom" ? radius : port === "top" ? -radius : 0) }; }
  if (node.shape === "start" || node.shape === "end" || node.shape === "terminal") { const rx2 = node.width / 2; const ry2 = node.height / 2; return { x: c.x + (port === "right" ? rx2 : port === "left" ? -rx2 : 0), y: c.y + (port === "bottom" ? ry2 : port === "top" ? -ry2 : 0) }; }
  const polygon = polygonPoints(node);
  return polygon ? polygonConnectionPoint(polygon, c, port, fallback) : fallback;
}
const near = (a, b) => Math.abs(a - b) <= ALIGNMENT_EPSILON;
const normalizedAxis = (a, b) => Math.round(((a + b) / 2) * 1000) / 1000;
const isHorizontallyAligned = (source, target) => near(source.y, target.y);
const isVerticallyAligned = (source, target) => near(source.x, target.x);
const normalizeHorizontalAxis = (source, target) => normalizedAxis(source.y, target.y);
const normalizeVerticalAxis = (source, target) => normalizedAxis(source.x, target.x);
const normalizeFlowNodeType = (shape) => ["start", "end", "connector"].includes(shape) ? "terminal" : shape;
const edgeStyle = (edge) => { const legacy = typeof edge.style === "string" ? edge.style : undefined; const style = typeof edge.style === "object" && edge.style ? edge.style : {}; const color = style.color ?? (edge.tone === "default" || !edge.tone ? "neutral" : edge.tone); const width = style.width ?? "medium"; return { color: EDGE_COLORS[color] ?? EDGE_COLORS.neutral, colorToken: color in EDGE_COLORS ? color : "neutral", width: EDGE_WIDTHS[width] ?? EDGE_WIDTHS.medium, widthToken: width in EDGE_WIDTHS ? width : "medium", dashed: style.dash === "dashed" || legacy === "dashed" }; };
const nodeStyle = (node) => { const fill = node.style?.fill ?? (node.tone === "default" || !node.tone ? "default" : node.tone); const stroke = node.style?.stroke ?? (node.tone === "default" || !node.tone ? "default" : node.tone); return { fill: NODE_FILLS[fill] ?? NODE_FILLS.default, stroke: NODE_STROKES[stroke] ?? NODE_STROKES.default, text: fill === "primary" ? "#08495a" : fill === "info" ? "#253b77" : fill === "success" ? "#195530" : fill === "warning" ? "#744300" : fill === "danger" ? "#7c211d" : "#26343b" }; };
const snapCoordinate = (value, grid = FLOWCHART_GRID_SIZE) => Math.round(value / grid) * grid;
const snapPoint = (point) => ({ x: snapCoordinate(point.x), y: snapCoordinate(point.y) });
function simplifyRoutePoints(source) { const normalized = []; source.forEach((input) => { const previous = normalized.at(-1); const point = { ...input }; if (previous) { if (near(point.x, previous.x)) point.x = previous.x; if (near(point.y, previous.y)) point.y = previous.y; if (point.x === previous.x && point.y === previous.y) return; } normalized.push(point); }); let index = 1; while (index < normalized.length - 1) { const a = normalized[index - 1]; const b = normalized[index]; const c = normalized[index + 1]; if ((a.x === b.x && b.x === c.x) || (a.y === b.y && b.y === c.y)) normalized.splice(index, 1); else index += 1; } return normalized; }
function snapRoutePoints(points) { return simplifyRoutePoints(points); }
function edgePoints(edge, from, to) {
  const ports = automaticPorts(from, to); const fromPort = edge.fromPort ?? ports[0]; const toPort = edge.toPort ?? ports[1]; const start = portPoint(from, fromPort); const end = portPoint(to, toPort);
  const horizontalPorts = ["left", "right"].includes(fromPort) && ["left", "right"].includes(toPort); const verticalPorts = ["top", "bottom"].includes(fromPort) && ["top", "bottom"].includes(toPort);
  if (horizontalPorts && isHorizontallyAligned(start, end)) { const commonY = normalizeHorizontalAxis(start, end); return simplifyRoutePoints([{ x: start.x, y: commonY }, { x: end.x, y: commonY }]); }
  if (verticalPorts && isVerticallyAligned(start, end)) { const commonX = normalizeVerticalAxis(start, end); return simplifyRoutePoints([{ x: commonX, y: start.y }, { x: commonX, y: end.y }]); }
  if (edge.waypoints?.length) { const checkpoints = [start, ...edge.waypoints.map(snapPoint), end]; const points = [start]; checkpoints.slice(1).forEach((point) => { const current = points.at(-1); if (!near(current.x, point.x) && !near(current.y, point.y)) points.push(horizontalPorts ? { x: point.x, y: current.y } : { x: current.x, y: point.y }); points.push(point); }); return snapRoutePoints(points); }
  if (["left", "right"].includes(fromPort)) { const midX = snapCoordinate((start.x + end.x) / 2); return snapRoutePoints([start, { x: midX, y: start.y }, { x: midX, y: end.y }, end]); }
  const midY = snapCoordinate((start.y + end.y) / 2); return snapRoutePoints([start, { x: start.x, y: midY }, { x: end.x, y: midY }, end]);
}
function edgePath(edge, from, to) { return edgePoints(edge, from, to).map((point, index) => `${index ? "L" : "M"} ${point.x} ${point.y}`).join(" "); }
function wrap(text, width) { const words = String(text ?? "").split(/\s+/).filter(Boolean); const limit = Math.max(8, Math.floor(width / 8)); const lines = []; let line = ""; words.forEach((word) => { const candidate = line ? `${line} ${word}` : word; if (line && candidate.length > limit) { lines.push(line); line = word; } else line = candidate; }); if (line || !lines.length) lines.push(line); return lines.slice(0, 6); }
function shapeElement(node) { const resolved = nodeStyle(node); const common = { class: `flowchart-node-shape flowchart-tone-${node.tone ?? "default"}`, fill: resolved.fill, stroke: resolved.stroke }; if (node.shape === "decision") return svg("polygon", { ...common, points: `${node.x + node.width / 2},${node.y} ${node.x + node.width},${node.y + node.height / 2} ${node.x + node.width / 2},${node.y + node.height} ${node.x},${node.y + node.height / 2}` }); if (node.shape === "input" || node.shape === "output") { const skew = Math.min(24, node.width * .16); const points = node.shape === "input" ? `${node.x + skew},${node.y} ${node.x + node.width},${node.y} ${node.x + node.width - skew},${node.y + node.height} ${node.x},${node.y + node.height}` : `${node.x},${node.y} ${node.x + node.width - skew},${node.y} ${node.x + node.width},${node.y + node.height} ${node.x + skew},${node.y + node.height}`; return svg("polygon", { ...common, points }); } if (node.shape === "connector") return svg("circle", { ...common, cx: node.x + node.width / 2, cy: node.y + node.height / 2, r: Math.min(node.width, node.height) / 2 }); if (node.shape === "document") { const wave = node.y + node.height - Math.min(14, node.height / 5); return svg("path", { ...common, d: `M ${node.x} ${node.y} H ${node.x + node.width} V ${wave} Q ${node.x + node.width * .75} ${node.y + node.height} ${node.x + node.width * .5} ${wave} Q ${node.x + node.width * .25} ${node.y + node.height} ${node.x} ${wave} Z` }); } if (node.shape === "note") return svg("path", { ...common, d: `M ${node.x} ${node.y} H ${node.x + node.width - 18} L ${node.x + node.width} ${node.y + 18} V ${node.y + node.height} H ${node.x} Z M ${node.x + node.width - 18} ${node.y} V ${node.y + 18} H ${node.x + node.width}` }); return svg("rect", { ...common, x: node.x, y: node.y, width: node.width, height: node.height, rx: normalizeFlowNodeType(node.shape) === "terminal" ? Math.min(node.height / 2, 40) : 10 }); }
function textElement(node, text) { const group = svg("text", { class: "flowchart-node-label", fill: nodeStyle(node).text, x: node.x + node.width / 2, y: node.y + node.height / 2, "text-anchor": "middle" }); const lines = wrap(text, node.width - 24); const start = node.y + node.height / 2 - ((lines.length - 1) * 16) / 2 + 5; lines.forEach((line, index) => { const span = svg("tspan", { x: node.x + node.width / 2, y: start + index * 16 }); span.textContent = line; group.append(span); }); return group; }
function resolveOptionalTranslation(context, key, technicalIds = []) { if (!key || typeof context.t !== "function") return null; const raw = context.t(key); const value = typeof raw === "string" ? raw.trim() : ""; const missing = !value || value === key || /^\[\[.*\]\]$/.test(value) || technicalIds.includes(value) || /^(?:edge|node|text)_\d+$/i.test(value); if (missing) { if (context.devMode && typeof console !== "undefined") console.warn(`[Flowchart] Traducción ausente: ${key}`); return null; } return value; }
function resolveText(context, key, devFallback = "", technicalIds = []) { return resolveOptionalTranslation(context, key, technicalIds) ?? (context.devMode ? devFallback : ""); }
function edgeLabelGeometry(text, edge, from, to) { const points = edgePoints(edge, from, to); let segment = [points[0], points[1]]; let longest = -1; for (let index = 1; index < points.length; index += 1) { const a = points[index - 1]; const b = points[index]; const length = Math.abs(b.x - a.x) + Math.abs(b.y - a.y); if (length > longest) { longest = length; segment = [a, b]; } } const [a, b] = segment; const horizontal = a.y === b.y; const x = (a.x + b.x) / 2 + (horizontal ? 0 : 10); const y = (a.y + b.y) / 2 + (horizontal ? -10 : 4); const width = Math.max(18, text.length * 7 + 12); return { x, y, width, height: 20, horizontal, minX: horizontal ? x - width / 2 : x - 4, minY: y - 14, maxX: horizontal ? x + width / 2 : x - 4 + width, maxY: y + 6 }; }
function edgeLabelElement(text, edge, from, to, tone) { const labelBounds = edgeLabelGeometry(text, edge, from, to); const group = svg("g", { class: `flowchart-edge-label flowchart-tone-${tone}` }); const label = svg("text", { x: labelBounds.x, y: labelBounds.y, "text-anchor": labelBounds.horizontal ? "middle" : "start" }); label.textContent = text; group.append(svg("rect", { x: labelBounds.minX, y: labelBounds.minY, width: labelBounds.width, height: labelBounds.height, rx: 4, fill: "#fff", "fill-opacity": ".86", stroke: "#d5e0e4" }), label); return group; }
function freeTextElement(text, value) { const align = text.align ?? "left"; const x = align === "center" ? text.x + text.width / 2 : align === "right" ? text.x + text.width : text.x; const attributes = { class: "flowchart-free-text", x, y: text.y + (text.fontSize ?? 18), "text-anchor": align === "center" ? "middle" : align === "right" ? "end" : "start", fill: text.color ?? "currentColor", "font-size": text.fontSize ?? 18, "font-weight": text.bold ? "700" : "400", "font-style": text.italic ? "italic" : "normal", "text-decoration": text.underline ? "underline" : "none" }; if (text.rotation === 0) attributes.transform = `rotate(0 ${x} ${text.y})`; const group = svg("text", attributes); String(value).split(/\r?\n/).forEach((line, index) => { const span = svg("tspan", { x, dy: index ? text.fontSize ?? 18 : 0 }); span.textContent = line; group.append(span); }); return group; }
function flowchartBounds(block, padding = 32, context = null) {
  const points = [];
  const includeRect = ({ minX, minY, maxX, maxY }) => points.push({ x: minX, y: minY }, { x: maxX, y: maxY });
  (block.nodes ?? []).forEach((node) => includeRect(nodeBounds(node)));
  (block.texts ?? []).forEach((text) => includeRect({ minX: text.x, minY: text.y, maxX: text.x + text.width, maxY: text.y + text.height }));
  const nodes = new Map((block.nodes ?? []).map((node) => [node.id, node]));
  (block.edges ?? []).forEach((edge) => {
    const from = nodes.get(edge.from); const to = nodes.get(edge.to);
    if (!from || !to) return;
    edgePoints(edge, from, to).forEach((point) => points.push(point));
    const label = context ? resolveOptionalTranslation(context, edge.labelKey, [edge.id]) : null;
    if (label) includeRect(edgeLabelGeometry(label, edge, from, to));
  });
  if (!points.length) points.push({ x: 0, y: 0 });
  const minX = Math.min(...points.map((point) => point.x)) - padding; const minY = Math.min(...points.map((point) => point.y)) - padding; const maxX = Math.max(...points.map((point) => point.x)) + padding; const maxY = Math.max(...points.map((point) => point.y)) + padding;
  return { minX, minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) };
}
function computeFlowchartView(block, context) {
  if (block.fit === "viewport") return { minX: 0, minY: 0, width: block.viewport?.width ?? 1200, height: block.viewport?.height ?? 720 };
  return flowchartBounds(block, 32, context);
}
function parseViewBox(svgNode) {
  const value = svgNode.getAttribute?.("viewBox") ?? svgNode.attributes?.viewBox ?? "";
  const [minX, minY, width, height] = String(value).split(/\s+/).map(Number);
  return [minX, minY, width, height].every(Number.isFinite) && width > 0 && height > 0 ? { minX, minY, width, height } : null;
}
function fitLightboxContent(stage, clone, sourceView) {
  const view = sourceView ?? parseViewBox(clone);
  if (!view) return;
  stage.dataset.zoomMode = "fit";
  clone.dataset.zoomMode = "fit";
  const viewportWidth = typeof window === "undefined" ? view.width : window.innerWidth;
  const viewportHeight = typeof window === "undefined" ? view.height : window.innerHeight;
  const stageWidth = Math.max(1, (stage.clientWidth || viewportWidth || view.width) - 32);
  const stageHeight = Math.max(1, (stage.clientHeight || viewportHeight || view.height) - 32);
  const scale = Math.min(stageWidth / view.width, stageHeight / view.height, 3);
  const fittedWidth = Math.max(1, view.width * scale);
  const fittedHeight = Math.max(1, view.height * scale);
  if (clone.style) {
    clone.style.width = `${fittedWidth}px`;
    clone.style.height = `${fittedHeight}px`;
  } else {
    clone.setAttribute("data-fit-width", fittedWidth.toFixed(3));
    clone.setAttribute("data-fit-height", fittedHeight.toFixed(3));
  }
  stage.scrollLeft = Math.max(0, (fittedWidth - (stage.clientWidth || fittedWidth)) / 2);
  stage.scrollTop = Math.max(0, (fittedHeight - (stage.clientHeight || fittedHeight)) / 2);
}
function openFlowchartLightbox(svgNode, label) {
  const previousFocus = document.activeElement;
  const overlay = element("div", { className: "flowchart-lightbox", role: "dialog", "aria-modal": "true", "aria-label": label });
  const close = element("button", { className: "flowchart-lightbox-close", type: "button", "aria-label": "Cerrar vista ampliada", text: "×" });
  const stage = element("div", { className: "flowchart-lightbox-stage", dataset: { zoomMode: "fit" } });
  const clone = svgNode.cloneNode(true);
  clone.classList.add("flowchart-lightbox-svg");
  clone.dataset.zoomMode = "fit";
  stage.append(clone);
  overlay.append(close, stage);
  document.body.append(overlay);
  document.body.classList.add("flowchart-lightbox-open");
  const sourceView = parseViewBox(svgNode);
  const scheduleFit = typeof requestAnimationFrame === "function" ? requestAnimationFrame : (callback) => setTimeout(callback, 0);
  scheduleFit(() => fitLightboxContent(stage, clone, sourceView));
  const closeOverlay = () => {
    document.removeEventListener("keydown", onKeydown);
    document.body.classList.remove("flowchart-lightbox-open");
    overlay.remove();
    if (previousFocus && typeof previousFocus.focus === "function") previousFocus.focus();
  };
  function onKeydown(event) { if (event.key === "Escape") closeOverlay(); }
  close.addEventListener("click", closeOverlay);
  overlay.addEventListener("click", (event) => { if (event.target === overlay) closeOverlay(); });
  document.addEventListener("keydown", onKeydown);
  close.focus();
}

export function renderFlowchart(block, context) {
  const view = computeFlowchartView(block, context); const wrapper = element("figure", { className: "flowchart-component" });
  const label = resolveOptionalTranslation(context, block.ariaLabelKey) ?? "Diagrama de flujo";
  const svgNode = svg("svg", { class: "flowchart-svg flowchart-open-target", viewBox: `${view.minX} ${view.minY} ${view.width} ${view.height}`, width: Math.ceil(view.width), height: Math.ceil(view.height), style: `--flowchart-view-width:${view.width}; --flowchart-view-height:${view.height};`, preserveAspectRatio: "xMidYMid meet", role: "img", "aria-label": label, tabindex: "0" }); const defs = svg("defs");
  Object.entries(EDGE_COLORS).forEach(([color, value]) => Object.entries(EDGE_WIDTHS).forEach(([width, strokeWidth]) => { const size = strokeWidth >= 3 ? 9 : 7; const marker = svg("marker", { id: `flowchart-arrow-${color}-${width}`, markerWidth: size, markerHeight: size, refX: size - 1, refY: size / 2, orient: "auto", markerUnits: "userSpaceOnUse" }); marker.append(svg("path", { d: `M 0 0 L ${size} ${size / 2} L 0 ${size} z`, fill: value })); defs.append(marker); })); svgNode.append(defs);
  const nodes = new Map((block.nodes ?? []).map((node) => [node.id, node])); const seen = new Set(); const edgeLayer = svg("g", { class: "flowchart-edges" });
  (block.edges ?? []).forEach((edge) => { const from = nodes.get(edge.from); const to = nodes.get(edge.to); if (!from || !to) return; const semantic = `${edge.from}|${edge.to}|${edge.fromPort ?? ""}|${edge.toPort ?? ""}`; if (seen.has(semantic)) return; seen.add(semantic); const resolved = edgeStyle(edge); const markerId = `flowchart-arrow-${resolved.colorToken}-${resolved.widthToken}`; const path = svg("path", { class: `flowchart-edge flowchart-edge-${resolved.colorToken}`, d: edgePath(edge, from, to), fill: "none", stroke: resolved.color, "stroke-width": resolved.width, "marker-end": edge.arrow === "none" ? "" : `url(#${markerId})` }); if (edge.arrow === "both") path.setAttribute("marker-start", `url(#${markerId})`); if (resolved.dashed) path.setAttribute("stroke-dasharray", "8 6"); edgeLayer.append(path); const edgeText = resolveOptionalTranslation(context, edge.labelKey, [edge.id]); if (edgeText) edgeLayer.append(edgeLabelElement(edgeText, edge, from, to, resolved.colorToken)); }); svgNode.append(edgeLayer);
  const textLayer = svg("g", { class: "flowchart-texts" }); (block.texts ?? []).forEach((text) => { const value = resolveOptionalTranslation(context, text.textKey, [text.id]); if (value) textLayer.append(freeTextElement(text, value)); }); svgNode.append(textLayer);
  const nodeLayer = svg("g", { class: "flowchart-nodes" }); (block.nodes ?? []).forEach((node) => { const group = svg("g", { class: `flowchart-node flowchart-tone-${node.tone ?? "default"}`, "data-node-id": node.id }); group.append(shapeElement(node), textElement(node, resolveText(context, node.labelKey, "Nodo sin etiqueta", [node.id]))); nodeLayer.append(group); }); svgNode.append(nodeLayer); svgNode.addEventListener("click", () => openFlowchartLightbox(svgNode, label)); svgNode.addEventListener("keydown", (event) => { if (event.key === "Enter" || event.key === " ") { event.preventDefault(); openFlowchartLightbox(svgNode, label); } }); wrapper.append(svgNode);
  if (block.captionKey) { const caption = resolveOptionalTranslation(context, block.captionKey); if (caption) wrapper.append(element("figcaption", { className: "flowchart-caption", text: caption })); }
  const accessible = element("ol", { className: "flowchart-accessibility sr-only" }); (block.nodes ?? []).forEach((node) => accessible.append(element("li", { text: resolveOptionalTranslation(context, node.labelKey, [node.id]) ?? "Nodo sin etiqueta" }))); (block.texts ?? []).forEach((text) => { const value = resolveOptionalTranslation(context, text.textKey, [text.id]); if (value) accessible.append(element("li", { text: value })); }); (block.edges ?? []).forEach((edge) => { const from = nodes.get(edge.from); const to = nodes.get(edge.to); if (from && to) { const edgeText = resolveOptionalTranslation(context, edge.labelKey, [edge.id]); const fromText = resolveOptionalTranslation(context, from.labelKey, [from.id]) ?? "Nodo sin etiqueta"; const toText = resolveOptionalTranslation(context, to.labelKey, [to.id]) ?? "Nodo sin etiqueta"; accessible.append(element("li", { text: `${fromText} → ${toText}${edgeText ? ` — ${edgeText}` : ""}` })); } }); wrapper.append(accessible); return wrapper;
}

const bounds = flowchartBounds;

export { ALIGNMENT_EPSILON, FLOWCHART_GRID_SIZE, automaticPorts, bounds, computeFlowchartView, edgePath, edgePoints, portPoint, resolveOptionalTranslation, simplifyRoutePoints, snapCoordinate, snapPoint, snapRoutePoints };
