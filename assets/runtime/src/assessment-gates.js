function stateFor(assessmentStates, testId) {
  if (assessmentStates instanceof Map) return assessmentStates.get(testId);
  return assessmentStates?.[testId];
}

export function findAssessmentGates(manual) {
  const gates = [];
  (manual.sections ?? []).forEach((section, sectionIndex) => {
    if (section.type !== "section") return;
    (section.blocks ?? []).forEach((block, blockIndex) => {
      if (block.type === "assessment" && block.navigationGate === true) {
        gates.push({ testId: block.testId, sectionId: section.id, sectionIndex, blockIndex, titleKey: block.titleKey });
      }
    });
  });
  return gates;
}

export function firstBlockingAssessmentGate(gates, assessmentStates) {
  return (gates ?? []).find((gate) => stateFor(assessmentStates, gate.testId)?.lastResult?.passed !== true) ?? null;
}

export function visibleSections(manual, gates, assessmentStates) {
  const blocking = firstBlockingAssessmentGate(gates, assessmentStates);
  if (!blocking) return manual.sections ?? [];
  return (manual.sections ?? []).filter((_, index) => index <= blocking.sectionIndex);
}

export function visibleManual(manual, gates, assessmentStates) {
  return { ...manual, sections: visibleSections(manual, gates, assessmentStates) };
}

export function canNavigateToSection(sectionId, manual, gates, assessmentStates) {
  const sectionIndex = (manual.sections ?? []).findIndex((section) => section.id === sectionId);
  if (sectionIndex < 0) return { ok: false, gate: null };
  const visibleIds = new Set(visibleSections(manual, gates, assessmentStates).map((section) => section.id));
  if (visibleIds.has(sectionId)) return { ok: true, gate: null };
  return { ok: false, gate: firstBlockingAssessmentGate(gates, assessmentStates) };
}
