export const RUNTIME_VERSION = "1.13.0";
export const SUPPORTED_FORMAT_VERSION = 1;
export const DEFAULT_MANUAL_ID = "demo_manual";

export function isValidId(value) {
  return typeof value === "string" && /^[a-z0-9][a-z0-9_-]*$/.test(value);
}

export function isSafeRelativePath(value) {
  if (typeof value !== "string" || value.length === 0 || value.includes("\\")) return false;
  if (value.startsWith("/") || /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value)) return false;
  return !value.split("/").some((part) => part === ".." || part === "" || part === ".");
}

export function parseSemVer(value) {
  const match = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/.exec(value ?? "");
  if (!match) return null;
  const prerelease = match[4]?.split(".") ?? [];
  if (prerelease.some((part) => part === "" || (/^\d+$/.test(part) && part.length > 1 && part.startsWith("0")))) return null;
  return { core: match.slice(1, 4).map(Number), prerelease };
}

export function compareSemVer(left, right) {
  const a = parseSemVer(left);
  const b = parseSemVer(right);
  if (!a || !b) throw new TypeError("Versión SemVer no válida");
  for (let index = 0; index < 3; index += 1) {
    if (a.core[index] !== b.core[index]) return a.core[index] < b.core[index] ? -1 : 1;
  }
  if (!a.prerelease.length || !b.prerelease.length) {
    if (a.prerelease.length === b.prerelease.length) return 0;
    return a.prerelease.length ? -1 : 1;
  }
  const length = Math.max(a.prerelease.length, b.prerelease.length);
  for (let index = 0; index < length; index += 1) {
    const leftPart = a.prerelease[index];
    const rightPart = b.prerelease[index];
    if (leftPart === undefined || rightPart === undefined) return leftPart === undefined ? -1 : 1;
    if (leftPart === rightPart) continue;
    const leftNumeric = /^\d+$/.test(leftPart);
    const rightNumeric = /^\d+$/.test(rightPart);
    if (leftNumeric && rightNumeric) return Number(leftPart) < Number(rightPart) ? -1 : 1;
    if (leftNumeric !== rightNumeric) return leftNumeric ? -1 : 1;
    return leftPart < rightPart ? -1 : 1;
  }
  return 0;
}

export function manualRoot(manualId) {
  if (!isValidId(manualId)) throw new Error("Identificador de manual no válido");
  return new URL(`../../manuals/${manualId}/`, import.meta.url);
}
