import { isValidId } from "./config.js";

export function hashSection() {
  const candidate = decodeURIComponent(window.location.hash.slice(1));
  return isValidId(candidate) ? candidate : null;
}

export function navigateHash(sectionId, smooth = true) {
  if (!isValidId(sectionId)) return false;
  const target = document.getElementById(sectionId);
  if (!target) return false;
  if (window.location.hash !== `#${sectionId}`) history.replaceState(history.state, "", `#${sectionId}`);
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  target.scrollIntoView({ behavior: smooth && !reduceMotion ? "smooth" : "auto", block: "start" });
  return true;
}
