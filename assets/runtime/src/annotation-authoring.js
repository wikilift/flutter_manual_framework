export function calculateAnnotationCoordinates(clientX, clientY, bounds) {
  if (!bounds || bounds.width <= 0 || bounds.height <= 0) throw new TypeError("El área de imagen no es válida");
  const clamp = (value) => Math.min(100, Math.max(0, value));
  return {
    x: Number(clamp(((clientX - bounds.left) / bounds.width) * 100).toFixed(2)),
    y: Number(clamp(((clientY - bounds.top) / bounds.height) * 100).toFixed(2)),
  };
}

export function annotationSnippet(coordinates, labelKey) {
  return JSON.stringify({ x: coordinates.x, y: coordinates.y, labelKey }, null, 2);
}
