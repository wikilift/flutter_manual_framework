export function sectionFallbackTitle(index, context = {}) {
  const label = context.ui?.sectionFallback ?? "Sección";
  return `${label} ${index + 1}`;
}

export function sectionTitle(section, index, context) {
  return section.titleKey ? context.t(section.titleKey) : sectionFallbackTitle(index, context);
}
