import { element } from "../dom.js";
import { appendHighlightedText } from "./paragraph.js";

function svg(tagName, options = {}, children = []) {
  const node = document.createElementNS("http://www.w3.org/2000/svg", tagName);
  for (const [key, value] of Object.entries(options)) {
    if (value === undefined || value === null) continue;
    node.setAttribute(key, String(value));
  }
  node.append(...children.filter(Boolean));
  return node;
}

export function assetFallback(context) {
  return element("p", { className: "media-fallback asset-fallback", text: context.ui.assetUnavailable });
}

function optionalMarkerText(context, key) {
  if (!key) return "";
  if (typeof context.optionalT === "function") return context.optionalT(key);
  const value = context.t(key);
  return typeof value === "string" && value.trim() && value !== key && !/^(?:\[\[.*\]\]|⟦.*⟧)$/.test(value) ? value.trim() : "";
}

export function optionalTranslationText(context, key) {
  return optionalMarkerText(context, key);
}

export function markerDetailNodes(markerData) {
  return [
    element("strong", { className: "annotation-title", text: markerData.label }),
    markerData.description ? element("span", { className: "annotation-description", text: markerData.description }) : null,
  ];
}

export function markerLegendContent(markerData) {
  return [
    element("span", { className: "annotation-number", text: String(markerData.number) }),
    element("span", { className: "annotation-legend-copy" }, [
      element("span", { className: "annotation-legend-label", text: markerData.label }),
      markerData.description ? element("span", { className: "annotation-legend-description", text: markerData.description }) : null,
    ]),
  ];
}

function overlayDetailNodes(overlayData) {
  return markerDetailNodes(overlayData);
}

function overlayLegendContent(overlayData) {
  return markerLegendContent(overlayData);
}

function rectangleBorderWidth(overlayData) {
  return Number.isFinite(overlayData.borderWidth) && overlayData.borderWidth > 0 ? overlayData.borderWidth : 2;
}

const OVERLAY_AUTHORING_WIDTH = 760;

function overlayAuthoringScale(renderedImageWidth, referenceWidth = OVERLAY_AUTHORING_WIDTH) {
  if (!Number.isFinite(renderedImageWidth) || renderedImageWidth <= 0 || !Number.isFinite(referenceWidth) || referenceWidth <= 0) return 1;
  return Math.round((renderedImageWidth / referenceWidth) * 1000) / 1000;
}

export function scaledOverlayCssPx(value, fallback, min = 0, max = 96) {
  const number = Number.isFinite(value) ? value : fallback;
  const base = Math.min(max, Math.max(min, Math.round(number * 100) / 100));
  return `clamp(${min}px, calc(${base}px * var(--annotation-scale, 1)), ${max}px)`;
}

export function rectangleTextNodes(overlayData) {
  if (!overlayData.text) return [];
  const text = element("span", { className: "annotation-rectangle-text", style: rectangleTextStyle(overlayData) });
  appendHighlightedText(text, overlayData.text, overlayData.textHighlights);
  return [text];
}

function rectangleTextStyle(overlayData) {
  const align = ["left", "center", "right"].includes(overlayData.textAlign) ? overlayData.textAlign : "center";
  const vertical = ["top", "middle", "bottom"].includes(overlayData.verticalAlign) ? overlayData.verticalAlign : "middle";
  return [
    `color:${validHex(overlayData.textColor) ? overlayData.textColor : "#26343b"}`,
    `background:${validHex(overlayData.backgroundColor) ? rgba(overlayData.backgroundColor, Number.isFinite(overlayData.backgroundOpacity) ? overlayData.backgroundOpacity : .12) : "transparent"}`,
    `border-radius:${scaledOverlayCssPx(clampCssPx(overlayData.cornerRadius, 8), 8, 0, 64)}`,
    `padding:${scaledOverlayCssPx(clampCssPx(overlayData.padding, 8), 8, 0, 64)}`,
    `font-size:${scaledOverlayCssPx(Number.isFinite(overlayData.fontSize) ? Math.min(72, Math.max(10, Math.round(overlayData.fontSize))) : 14, 14, 7, 72)}`,
    `text-align:${align}`,
    `align-items:${vertical === "top" ? "flex-start" : vertical === "bottom" ? "flex-end" : "center"}`,
    `justify-content:${align === "left" ? "flex-start" : align === "right" ? "flex-end" : "center"}`,
  ].join(";");
}

function validHex(value) {
  return /^#[0-9a-fA-F]{6}$/.test(String(value ?? ""));
}

function rgba(hex, opacity) {
  const value = hex.replace("#", "");
  const alpha = Math.min(1, Math.max(0, opacity));
  return `rgb(${parseInt(value.slice(0, 2), 16)} ${parseInt(value.slice(2, 4), 16)} ${parseInt(value.slice(4, 6), 16)} / ${alpha})`;
}

function clampCssPx(value, fallback) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(64, Math.max(0, Math.round(number))) : fallback;
}

export function rectangleFillStyle(overlayData) {
  return [`stroke:${overlayColor(overlayData)}`, `opacity:${overlayOpacity(overlayData)}`].join(";");
}

export function rectangleSvgRadius(overlayData) {
  return Number.isFinite(overlayData.cornerRadius) ? Math.max(0, overlayData.cornerRadius / 4) : undefined;
}

const TONE_COLORS = { neutral: "#536670", info: "#21768e", success: "#2d7c4b", warning: "#a7610b", danger: "#b53b35" };

export function overlayTone(overlay) {
  return overlay.style?.colorMode === "tone" && overlay.style?.tone ? overlay.style.tone : overlay.tone ?? "neutral";
}

export function overlayColor(overlay) {
  if (overlay.style?.colorMode === "custom" && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(String(overlay.style.color ?? ""))) return overlay.style.color;
  return TONE_COLORS[overlayTone(overlay)] ?? TONE_COLORS.neutral;
}

export function overlayStrokeWidth(overlay) {
  const fallback = overlay.type === "rectangle" ? rectangleBorderWidth(overlay) : 3;
  const value = Number(overlay.style?.strokeWidth ?? fallback);
  if (!Number.isFinite(value) || value <= 0) return fallback;
  return Math.min(16, Math.max(1, value));
}

export function overlayOpacity(overlay) {
  const value = Number(overlay.style?.opacity ?? 1);
  return Number.isFinite(value) ? Math.min(1, Math.max(0.1, value)) : 1;
}

export function overlayPoints(overlay) {
  if (overlay.type === "route") return Array.isArray(overlay.points) ? overlay.points : [];
  return [overlay.start, overlay.end].filter(Boolean);
}

export function overlayPath(points) {
  return points.length ? `M ${points[0].x} ${points[0].y}${points.slice(1).map((point) => ` L ${point.x} ${point.y}`).join("")}` : "";
}

function overlayDistance(a, b) {
  return Math.hypot(Number(b?.x ?? 0) - Number(a?.x ?? 0), Number(b?.y ?? 0) - Number(a?.y ?? 0));
}

function overlayVectorLength(points) {
  return points.slice(1).reduce((total, point, index) => total + overlayDistance(points[index], point), 0);
}

export function overlayArrowSize(overlay) {
  const length = overlayVectorLength(overlayPoints(overlay));
  if (length < 1) return null;
  return Math.round(Math.min(8, Math.max(2, Math.min(overlayStrokeWidth(overlay) * 2.8, length * 0.35))) * 100) / 100;
}

function roundGeometryPoint(point) {
  return { x: Math.round(Number(point.x) * 1000) / 1000, y: Math.round(Number(point.y) * 1000) / 1000 };
}

function overlayWantsStartHead(overlay) {
  return overlay.arrowHead === "start" || overlay.arrowHead === "both";
}

function overlayWantsEndHead(overlay) {
  if (overlay.type === "arrow") return overlay.arrowHead !== "none";
  return overlay.arrowHead === "end" || overlay.arrowHead === "both";
}

function overlayDirection(from, to) {
  const length = overlayDistance(from, to);
  if (length < 1) return null;
  return { x: (Number(to.x) - Number(from.x)) / length, y: (Number(to.y) - Number(from.y)) / length };
}

function overlayArrowHeadGeometry(tip, adjacent, desiredLength, desiredWidth, maxFraction) {
  const segmentLength = overlayDistance(tip, adjacent);
  const direction = overlayDirection(adjacent, tip);
  if (!direction) return null;
  const length = Math.round(Math.min(desiredLength, Math.max(0, segmentLength * maxFraction)) * 1000) / 1000;
  if (length <= 0) return null;
  const width = Math.round(desiredWidth * (length / desiredLength) * 1000) / 1000;
  const baseCenter = roundGeometryPoint({ x: Number(tip.x) - direction.x * length, y: Number(tip.y) - direction.y * length });
  const perpendicular = { x: -direction.y, y: direction.x };
  const halfWidth = width / 2;
  return {
    tip: roundGeometryPoint(tip),
    baseCenter,
    leftBase: roundGeometryPoint({ x: baseCenter.x + perpendicular.x * halfWidth, y: baseCenter.y + perpendicular.y * halfWidth }),
    rightBase: roundGeometryPoint({ x: baseCenter.x - perpendicular.x * halfWidth, y: baseCenter.y - perpendicular.y * halfWidth }),
    length,
    width,
  };
}

export function overlayArrowGeometry(overlay) {
  const points = overlayPoints(overlay);
  if (overlay.type === "line" || points.length < 2) return { shaftPoints: points, startHead: null, endHead: null };
  const desiredLength = overlayArrowSize(overlay);
  if (!desiredLength) return { shaftPoints: points, startHead: null, endHead: null };
  const strokeWidth = overlayStrokeWidth(overlay);
  const desiredWidth = Math.round(Math.min(desiredLength * 1.18, Math.max(desiredLength, strokeWidth * 1.35)) * 100) / 100;
  const sameSegment = points.length === 2 && overlayWantsStartHead(overlay) && overlayWantsEndHead(overlay);
  const maxFraction = sameSegment ? 0.45 : 0.82;
  const shaftPoints = [...points];
  const startHead = overlayWantsStartHead(overlay) ? overlayArrowHeadGeometry(points[0], points[1], desiredLength, desiredWidth, maxFraction) : null;
  const endHead = overlayWantsEndHead(overlay) ? overlayArrowHeadGeometry(points[points.length - 1], points[points.length - 2], desiredLength, desiredWidth, maxFraction) : null;
  if (startHead) shaftPoints[0] = startHead.baseCenter;
  if (endHead) shaftPoints[shaftPoints.length - 1] = endHead.baseCenter;
  return { shaftPoints, startHead, endHead };
}

export function overlayShaftPath(overlay) {
  return overlayPath(overlayArrowGeometry(overlay).shaftPoints);
}

export function overlayArrowHeadPath(head) {
  return `M ${head.tip.x} ${head.tip.y} L ${head.leftBase.x} ${head.leftBase.y} L ${head.rightBase.x} ${head.rightBase.y} Z`;
}

export function overlayTooltipClass(overlay) {
  const x = overlay.type === "rectangle" ? Number(overlay.x) + Number(overlay.width ?? 0) : Number(overlay.x);
  const y = overlay.type === "rectangle" ? Number(overlay.y) + Number(overlay.height ?? 0) : Number(overlay.y);
  return [
    x >= 72 ? "annotation-tooltip-left" : x <= 28 ? "annotation-tooltip-right" : "annotation-tooltip-center",
    y >= 72 ? "annotation-tooltip-above" : "annotation-tooltip-below",
  ].join(" ");
}

function rectFromDomRect(rect) {
  return { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height };
}

function viewportBounds() {
  const width = globalThis.innerWidth || document.documentElement?.clientWidth || 390;
  const height = globalThis.innerHeight || document.documentElement?.clientHeight || 844;
  return { left: 0, top: 0, right: width, bottom: height, width, height };
}

function intersectBounds(a, b) {
  const left = Math.max(a.left, b.left);
  const top = Math.max(a.top, b.top);
  const right = Math.min(a.right, b.right);
  const bottom = Math.min(a.bottom, b.bottom);
  return { left, top, right, bottom, width: Math.max(0, right - left), height: Math.max(0, bottom - top) };
}

function tooltipBounds(root) {
  const stage = root.querySelector?.(".annotation-stage") ?? root.querySelector?.(".annotation-surface") ?? root;
  const rect = typeof stage.getBoundingClientRect === "function" ? rectFromDomRect(stage.getBoundingClientRect()) : viewportBounds();
  return intersectBounds(rect.width && rect.height ? rect : viewportBounds(), viewportBounds());
}

export function computeTooltipPlacement(triggerRect, boundsRect, preferredSize = {}, options = {}) {
  const margin = options.margin ?? 12;
  const gap = options.gap ?? 10;
  const minWidth = Math.min(options.minWidth ?? 192, Math.max(120, boundsRect.width - margin * 2));
  const maxWidth = Math.min(options.maxWidth ?? 360, Math.max(minWidth, boundsRect.width - margin * 2));
  const width = Math.max(minWidth, Math.min(preferredSize.width || maxWidth, maxWidth));
  const height = Math.max(40, preferredSize.height || 96);
  const maxHeight = Math.max(80, boundsRect.height - margin * 2);
  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
  const centerX = triggerRect.left + triggerRect.width / 2;
  const centerY = triggerRect.top + triggerRect.height / 2;
  const candidates = [
    { placement: "bottom", left: centerX - width / 2, top: triggerRect.bottom + gap, primarySpace: boundsRect.bottom - triggerRect.bottom - gap },
    { placement: "top", left: centerX - width / 2, top: triggerRect.top - gap - height, primarySpace: triggerRect.top - boundsRect.top - gap },
    { placement: "right", left: triggerRect.right + gap, top: centerY - height / 2, primarySpace: boundsRect.right - triggerRect.right - gap },
    { placement: "left", left: triggerRect.left - gap - width, top: centerY - height / 2, primarySpace: triggerRect.left - boundsRect.left - gap },
  ].map((candidate) => {
    const left = clamp(candidate.left, boundsRect.left + margin, boundsRect.right - margin - width);
    const top = clamp(candidate.top, boundsRect.top + margin, boundsRect.bottom - margin - Math.min(height, maxHeight));
    const visibleWidth = Math.max(0, Math.min(left + width, boundsRect.right - margin) - Math.max(left, boundsRect.left + margin));
    const visibleHeight = Math.max(0, Math.min(top + height, boundsRect.bottom - margin) - Math.max(top, boundsRect.top + margin));
    return { ...candidate, left, top, score: candidate.primarySpace + visibleWidth + visibleHeight };
  });
  const best = candidates.sort((a, b) => b.score - a.score)[0] ?? candidates[0];
  return {
    placement: best.placement,
    left: Math.round(best.left),
    top: Math.round(best.top),
    width: Math.round(width),
    maxHeight: Math.round(maxHeight),
    arrowX: Math.round(clamp(centerX - best.left, 14, width - 14)),
    arrowY: Math.round(clamp(centerY - best.top, 14, Math.min(height, maxHeight) - 14)),
  };
}

function activeTooltipEntry(entries, activeOverlayId) {
  return entries.find((entry) => entry.id === activeOverlayId) ?? null;
}

function positionOverlayTooltip(root, entries, activeOverlayId) {
  const entry = activeTooltipEntry(entries, activeOverlayId);
  const label = entry?.trigger?.querySelector?.(".annotation-label");
  if (!entry || !label || typeof entry.trigger.getBoundingClientRect !== "function" || typeof label.getBoundingClientRect !== "function") return;
  const triggerRect = rectFromDomRect(entry.trigger.getBoundingClientRect());
  label.style.visibility = "hidden";
  label.style.removeProperty("--annotation-tooltip-left");
  label.style.removeProperty("--annotation-tooltip-top");
  const measured = label.getBoundingClientRect();
  const placement = computeTooltipPlacement(triggerRect, tooltipBounds(root), { width: measured.width, height: measured.height });
  label.dataset.tooltipPlacement = placement.placement;
  label.style.setProperty("--annotation-tooltip-left", `${placement.left - triggerRect.left}px`);
  label.style.setProperty("--annotation-tooltip-top", `${placement.top - triggerRect.top}px`);
  label.style.setProperty("--annotation-tooltip-width", `${placement.width}px`);
  label.style.setProperty("--annotation-tooltip-max-height", `${placement.maxHeight}px`);
  label.style.setProperty("--annotation-tooltip-arrow-x", `${placement.arrowX}px`);
  label.style.setProperty("--annotation-tooltip-arrow-y", `${placement.arrowY}px`);
  label.style.visibility = "";
}

function overlayAnimationClass(overlay) {
  return overlay.animation === "pulse" ? "annotation-overlay-pulse" : "";
}

export function syncAnnotationLayer(stage, imageNode) {
  if (typeof ResizeObserver === "undefined" || typeof imageNode?.getBoundingClientRect !== "function") return;
  const sync = () => {
    const imageRect = imageNode.getBoundingClientRect();
    if (imageRect.width) stage.style.setProperty("--annotation-scale", String(overlayAuthoringScale(imageRect.width)));
    if (stage.querySelector?.(".annotation-surface")) return;
    const stageRect = stage.getBoundingClientRect();
    if (!imageRect.width || !imageRect.height || !stageRect.width || !stageRect.height) return;
    stage.style.setProperty("--annotation-layer-left", `${imageRect.left - stageRect.left}px`);
    stage.style.setProperty("--annotation-layer-top", `${imageRect.top - stageRect.top}px`);
    stage.style.setProperty("--annotation-layer-width", `${imageRect.width}px`);
    stage.style.setProperty("--annotation-layer-height", `${imageRect.height}px`);
  };
  imageNode.addEventListener?.("load", sync);
  requestAnimationFrame(sync);
  const observer = new ResizeObserver(sync);
  observer.observe(stage);
  observer.observe(imageNode);
}

function closestClass(node, className) {
  return typeof node?.closest === "function" ? node.closest(`.${className}`) : null;
}

export function bindSingleActiveOverlay(root, entries) {
  let activeOverlayId = null;
  let activeTrigger = null;
  let tooltipFrame = 0;

  const scheduleTooltipPosition = () => {
    if (tooltipFrame) globalThis.cancelAnimationFrame?.(tooltipFrame);
    const schedule = globalThis.requestAnimationFrame ?? ((callback) => setTimeout(callback, 0));
    tooltipFrame = schedule(() => {
      tooltipFrame = 0;
      positionOverlayTooltip(root, entries, activeOverlayId);
    });
  };

  const applyActiveOverlay = (nextOverlayId, trigger = null) => {
    const previousTrigger = activeTrigger;
    activeOverlayId = nextOverlayId;
    activeTrigger = trigger;
    entries.forEach((entry) => {
      const active = entry.id === activeOverlayId;
      entry.trigger.classList.toggle("is-expanded", active);
      entry.visual?.classList.toggle("is-expanded", active);
      entry.trigger.setAttribute("aria-expanded", String(active));
      entry.legendTrigger?.classList.toggle("is-expanded", active);
      entry.legendItem?.classList.toggle("is-expanded", active);
    });
    if (activeOverlayId) scheduleTooltipPosition();
    return previousTrigger;
  };

  const closeActiveOverlay = (restoreFocus = false) => {
    const previousTrigger = applyActiveOverlay(null);
    if (restoreFocus && previousTrigger?.focus) previousTrigger.focus();
  };

  entries.forEach((entry) => {
    entry.trigger.setAttribute("aria-expanded", "false");
    entry.trigger.addEventListener("click", (event) => {
      event.stopPropagation();
      if (activeOverlayId === entry.id && closestClass(event.target, "annotation-label")) return;
      applyActiveOverlay(activeOverlayId === entry.id ? null : entry.id, entry.trigger);
    });
    entry.legendTrigger?.addEventListener("click", (event) => {
      event.stopPropagation();
      applyActiveOverlay(activeOverlayId === entry.id ? null : entry.id, entry.trigger);
      if (activeOverlayId === entry.id) entry.trigger.focus();
    });
  });

  const rootClick = (event) => {
    if (!closestClass(event.target, "annotation-marker") && !closestClass(event.target, "annotation-rectangle-button") && !closestClass(event.target, "annotation-legend")) closeActiveOverlay();
  };
  const documentClick = (event) => {
    if (!root.contains(event.target)) closeActiveOverlay();
  };
  const documentKeydown = (event) => {
    if (event.key === "Escape") closeActiveOverlay(true);
  };

  root.addEventListener("click", rootClick);
  document.addEventListener("click", documentClick);
  document.addEventListener("keydown", documentKeydown);
  globalThis.addEventListener?.("resize", scheduleTooltipPosition);
  document.addEventListener?.("scroll", scheduleTooltipPosition, true);
  const resizeObserver = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(scheduleTooltipPosition);
  if (resizeObserver) {
    resizeObserver.observe(root);
    entries.forEach((entry) => resizeObserver.observe(entry.trigger));
  }

  return {
    get activeOverlayId() { return activeOverlayId; },
    close: closeActiveOverlay,
    dispose: () => {
      if (tooltipFrame) globalThis.cancelAnimationFrame?.(tooltipFrame);
      document.removeEventListener?.("click", documentClick);
      document.removeEventListener?.("keydown", documentKeydown);
      document.removeEventListener?.("scroll", scheduleTooltipPosition, true);
      globalThis.removeEventListener?.("resize", scheduleTooltipPosition);
      resizeObserver?.disconnect();
    },
  };
}

function annotationStage(image, img, context) {
  const overlays = (image.overlays ?? []).filter((overlay) => overlay.visible !== false);
  if (!overlays.length) return { node: img, overlays: [] };
  const imageNode = img.matches?.("img") ? img : img.querySelector?.("img");
  const surface = element("div", { className: "annotation-surface" }, [img]);
  const stage = element("div", { className: "annotation-stage" }, [surface]);
  const legend = element("ol", { className: "annotation-legend" });
  const layer = element("div", { className: "annotation-layer" });
  const overlaySvg = svg("svg", { class: "annotation-overlay-svg", viewBox: "0 0 100 100", preserveAspectRatio: "none", "aria-hidden": "true" });
  layer.append(overlaySvg);
  const stageId = String(image.id ?? image.altKey ?? "image").replace(/[^a-zA-Z0-9_-]+/g, "-");
  const resolved = overlays.map((overlay, index) => ({ ...overlay, number: index + 1, label: context.t(overlay.labelKey), description: optionalMarkerText(context, overlay.descriptionKey), text: overlay.type === "rectangle" ? optionalMarkerText(context, overlay.textKey) : "" }));
  const activationEntries = [];
  resolved.forEach((overlayData) => {
    const index = overlayData.number - 1;
    const detailId = `annotation-detail-${stageId}-${overlayData.id}-${index}`;
    if (overlayData.type === "rectangle") {
      if (overlayData.animation === "pulse") overlaySvg.append(svg("rect", { class: `annotation-rectangle-halo annotation-overlay-halo annotation-tone-${overlayTone(overlayData)}`, x: overlayData.x, y: overlayData.y, width: overlayData.width, height: overlayData.height, rx: rectangleSvgRadius(overlayData), style: `${rectangleFillStyle(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData) + 5, 7, 2, 24)}` }));
      const rect = svg("rect", { class: `annotation-rectangle annotation-tone-${overlayTone(overlayData)} ${overlayAnimationClass(overlayData)}`, x: overlayData.x, y: overlayData.y, width: overlayData.width, height: overlayData.height, rx: rectangleSvgRadius(overlayData), style: `${rectangleFillStyle(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData), 2, 1, 16)}` });
      overlaySvg.append(rect);
      const trigger = element("button", {
        type: "button", className: `annotation-rectangle-button annotation-tone-${overlayTone(overlayData)}`,
        style: `--annotation-x:${overlayData.x}%;--annotation-y:${overlayData.y}%;--annotation-width:${overlayData.width}%;--annotation-height:${overlayData.height}%`,
        dataset: { annotationIndex: String(index), overlayType: "rectangle" },
        "aria-label": `${overlayData.number}. ${overlayData.label}`,
        "aria-controls": detailId,
        "aria-expanded": "false",
        "aria-describedby": overlayData.description ? detailId : undefined,
      }, [...rectangleTextNodes(overlayData), element("span", { id: detailId, className: `annotation-label ${overlayTooltipClass(overlayData)}` }, overlayDetailNodes(overlayData))]);
      layer.append(trigger);
      const legendButton = overlayData.showLegend === false ? null : element("button", { type: "button", className: `annotation-tone-${overlayTone(overlayData)}` }, overlayLegendContent(overlayData));
      const legendItem = legendButton ? element("li", { className: `annotation-tone-${overlayTone(overlayData)} annotation-type-rectangle` }, [legendButton]) : null;
      activationEntries.push({ id: overlayData.id, trigger, visual: rect, legendTrigger: legendButton, legendItem });
      if (legendItem) legend.append(legendItem);
      return;
    }
    if (["line", "arrow", "route"].includes(overlayData.type)) {
      const points = overlayPoints(overlayData);
      if (points.length < 2) return;
      const geometry = overlayArrowGeometry(overlayData);
      const shaftPath = overlayPath(geometry.shaftPoints);
      if (overlayData.animation === "pulse") {
        overlaySvg.append(svg("path", { class: `annotation-vector-halo annotation-overlay-halo annotation-vector-${overlayData.type} annotation-tone-${overlayTone(overlayData)}`, d: shaftPath, style: `stroke:${overlayColor(overlayData)};opacity:${overlayOpacity(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData) + 6, 9, 3, 28)}` }));
        [geometry.startHead, geometry.endHead].filter(Boolean).forEach((head) => overlaySvg.append(svg("path", { class: `annotation-arrow-head-halo annotation-overlay-halo annotation-tone-${overlayTone(overlayData)}`, d: overlayArrowHeadPath(head), style: `stroke:${overlayColor(overlayData)};opacity:${overlayOpacity(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData) + 6, 9, 3, 28)}` })));
      }
      overlaySvg.append(svg("path", { class: `annotation-vector annotation-vector-${overlayData.type} annotation-tone-${overlayTone(overlayData)} ${overlayAnimationClass(overlayData)}`, d: shaftPath, style: `stroke:${overlayColor(overlayData)};opacity:${overlayOpacity(overlayData)};stroke-width:${scaledOverlayCssPx(overlayStrokeWidth(overlayData), 3, 1, 16)}` }));
      [geometry.startHead, geometry.endHead].filter(Boolean).forEach((head) => overlaySvg.append(svg("path", { class: `annotation-arrow-head annotation-tone-${overlayTone(overlayData)} ${overlayAnimationClass(overlayData)}`, d: overlayArrowHeadPath(head), style: `fill:${overlayColor(overlayData)};stroke:${overlayColor(overlayData)};opacity:${overlayOpacity(overlayData)}` })));
      if (overlayData.showLegend !== false) {
        const legendButton = element("button", { type: "button", className: `annotation-tone-${overlayTone(overlayData)}` }, overlayLegendContent(overlayData));
        const legendItem = element("li", { className: `annotation-tone-${overlayTone(overlayData)} annotation-type-${overlayData.type}` }, [legendButton]);
        legend.append(legendItem);
      }
      return;
    }
    const marker = element("button", {
      type: "button", className: `annotation-marker annotation-tone-${overlayTone(overlayData)} ${overlayAnimationClass(overlayData)}`,
      style: `--annotation-x:${overlayData.x}%;--annotation-y:${overlayData.y}%;--annotation-color:${overlayColor(overlayData)}`,
      dataset: { annotationIndex: String(index) },
      "aria-label": `${overlayData.number}. ${overlayData.label}`,
      "aria-controls": detailId,
      "aria-expanded": "false",
      "aria-describedby": overlayData.description ? detailId : undefined,
    }, [element("span", { className: "annotation-number", text: String(overlayData.number) }), element("span", { id: detailId, className: `annotation-label ${overlayTooltipClass(overlayData)}` }, overlayDetailNodes(overlayData))]);
    layer.append(marker);
    const legendButton = overlayData.showLegend === false ? null : element("button", { type: "button", className: `annotation-tone-${overlayTone(overlayData)}` }, overlayLegendContent(overlayData));
    const legendItem = legendButton ? element("li", { className: `annotation-tone-${overlayTone(overlayData)} annotation-type-marker` }, [legendButton]) : null;
    activationEntries.push({ id: overlayData.id, trigger: marker, legendTrigger: legendButton, legendItem });
    if (legendItem) legend.append(legendItem);
  });
  surface.append(layer);
  const container = element("div", { className: "annotated-media" }, [stage, legend]);
  bindSingleActiveOverlay(container, activationEntries);
  syncAnnotationLayer(stage, imageNode);
  return { node: container, overlays: resolved };
}

export function mediaFigure(image, context, className = "media-figure") {
  const alt = image.decorative ? "" : context.t(image.altKey);
  const src = context.assetUrl(image);
  const caption = optionalTranslationText(context, image.captionKey);
  if (!src) return element("figure", { className }, [assetFallback(context), caption ? element("figcaption", { text: caption }) : null]);
  const img = element("img", {
    src,
    alt,
    loading: image.eager || context.printMode ? "eager" : "lazy",
    decoding: "async",
    className: image.objectFit ? `fit-${image.objectFit}` : "",
    dataset: { sectionId: context.sectionId ?? "", blockIndex: context.blockIndex ?? "", assetSrc: src },
  });
  const buttonLabel = alt ? `${alt}. Ampliar imagen` : "Ampliar imagen";
  const button = element("button", { type: "button", className: "media-button", "aria-label": buttonLabel }, [img]);
  const hasOverlays = (image.overlays ?? []).some((overlay) => overlay.visible !== false);
  const staged = annotationStage(image, hasOverlays ? img : button, context);
  img.addEventListener("error", () => staged.node.replaceWith(assetFallback(context)), { once: true });
  if (hasOverlays) img.addEventListener("click", () => context.openLightbox({ src: img.src, alt, caption, overlays: staged.overlays }));
  else button.addEventListener("click", () => context.openLightbox({ src: img.src, alt, caption, overlays: staged.overlays }));
  return element("figure", { className }, [staged.node, caption ? element("figcaption", { text: caption }) : null]);
}
