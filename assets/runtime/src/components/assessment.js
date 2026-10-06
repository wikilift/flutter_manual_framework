import { element } from "../dom.js";
import { mediaFigure, optionalTranslationText } from "./shared.js";

function stableIds(values) {
  return [...new Set((values ?? []).map((value) => String(value)).filter(Boolean))].sort();
}

function sameIds(left, right) {
  const a = stableIds(left);
  const b = stableIds(right);
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

export function scoreAssessment(block, answers = {}) {
  const questions = Array.isArray(block.questions) ? block.questions : [];
  const totalQuestions = questions.length;
  let correctAnswers = 0;
  questions.forEach((question) => {
    const validOptions = new Set((question.options ?? []).map((option) => option.id));
    const expected = (question.options ?? []).filter((option) => option.correct === true).map((option) => option.id);
    const selected = stableIds(answers[question.id]).filter((optionId) => validOptions.has(optionId));
    if (expected.length && sameIds(selected, expected)) correctAnswers += 1;
  });
  const score = totalQuestions ? Math.round((correctAnswers / totalQuestions) * 100) : 0;
  const passingScore = normalizePassingScore(block.passingScore);
  return { correctAnswers, totalQuestions, score, passingScore, passed: score >= passingScore };
}

function normalizePassingScore(value) {
  const number = Number(value ?? 80);
  return Number.isFinite(number) ? Math.min(100, Math.max(0, Math.round(number))) : 80;
}

function normalizeMaxAttempts(value) {
  const number = Number(value ?? 0);
  return Number.isInteger(number) && number >= 0 ? number : 0;
}

function attemptLabel(ui, attempt, maxAttempts) {
  return maxAttempts > 0 ? `${ui.assessmentAttempt} ${attempt} ${ui.assessmentAttemptOf} ${maxAttempts}` : `${ui.assessmentAttempt} ${attempt}`;
}

function canSubmit(block, answers) {
  return (block.questions ?? []).every((question) => stableIds(answers[question.id]).length > 0);
}

function selectedAnswers(form, block) {
  const data = new FormData(form);
  const answers = {};
  (block.questions ?? []).forEach((question) => {
    answers[question.id] = data.getAll(question.id).map(String);
  });
  return answers;
}

function questionMode(question) {
  return (question.options ?? []).filter((option) => option.correct === true).length > 1 ? "checkbox" : "radio";
}

export function assessmentTitle(block, context) {
  return block.titleKey ? context.t(block.titleKey) : context.ui?.assessmentTitleFallback ?? "Test";
}

export function assessmentOptionFeedback(option, selectedOptionIds = [], evaluated = false) {
  if (!evaluated) return "neutral";
  if (option.correct === true) return "correct";
  return stableIds(selectedOptionIds).includes(option.id) ? "incorrect" : "neutral";
}

function assessmentOptionClass(option, selectedOptionIds, evaluated) {
  const feedback = assessmentOptionFeedback(option, selectedOptionIds, evaluated);
  return feedback === "neutral" ? "assessment-option" : `assessment-option is-${feedback}`;
}

function resultNodes(ui, state, block) {
  if (!state?.lastResult) return [];
  const result = state.lastResult;
  const maxAttempts = normalizeMaxAttempts(block.maxAttempts);
  const exhausted = !result.passed && maxAttempts > 0 && state.attempts >= maxAttempts;
  return [element("output", { className: `assessment-result ${result.passed ? "is-passed" : "is-failed"}`, role: "status", "aria-live": "polite", tabindex: "-1" }, [
    element("strong", { text: `${ui.assessmentScore}: ${result.score}%` }),
    element("span", { text: `${ui.assessmentResult}: ${result.passed ? ui.assessmentPassed : ui.assessmentFailed}` }),
    element("span", { text: attemptLabel(ui, state.attempts, maxAttempts) }),
    exhausted ? element("span", { className: "assessment-exhausted", text: ui.assessmentAttemptsExhausted }) : null,
    result.passed && block.navigationGate === true ? element("span", { className: "assessment-continue", text: ui.assessmentContinue }) : null,
  ])];
}

export function renderAssessment(block, context) {
  const ui = context.ui;
  const testId = String(block.testId ?? "");
  const state = context.assessments?.get(testId) ?? { attempts: 0, lastResult: null, answers: {} };
  const maxAttempts = normalizeMaxAttempts(block.maxAttempts);
  const exhausted = !state.lastResult?.passed && maxAttempts > 0 && state.attempts >= maxAttempts;
  const locked = state.lastResult != null;
  const evaluated = state.lastResult != null;
  const title = assessmentTitle(block, context);
  const description = optionalTranslationText(context, block.descriptionKey);
  const form = element("form", { className: "assessment", dataset: { testId, navigationGate: String(block.navigationGate === true) } });
  form.append(element("div", { className: "assessment-header" }, [
    element("h3", { text: title }),
    description ? element("p", { className: "assessment-description", text: description }) : null,
    element("p", { className: "assessment-meta", text: `${ui.assessmentPassingScore}: ${normalizePassingScore(block.passingScore)}% · ${maxAttempts > 0 ? `${ui.assessmentMaxAttempts}: ${maxAttempts}` : ui.assessmentUnlimitedAttempts} · ${block.navigationGate === true ? ui.assessmentGateEnabled : ui.assessmentGateDisabled}` }),
    element("p", { className: "assessment-attempt", text: attemptLabel(ui, state.attempts + (state.lastResult ? 0 : 1), maxAttempts) }),
  ]));
  (block.questions ?? []).forEach((question, questionIndex) => {
    const mode = questionMode(question);
    const fieldset = element("fieldset", { className: "assessment-question" }, [
      element("legend", { text: `${ui.assessmentQuestion} ${questionIndex + 1}. ${context.t(question.textKey)}` }),
    ]);
    if (question.image) fieldset.append(mediaFigure(question.image, context, "media-figure assessment-question-image"));
    (question.options ?? []).forEach((option) => {
      const input = element("input", { type: mode, name: question.id, value: option.id, disabled: locked || exhausted });
      const selectedIds = stableIds(state.answers?.[question.id]);
      const selected = selectedIds.includes(option.id);
      if (selected) input.checked = true;
      fieldset.append(element("label", { className: assessmentOptionClass(option, selectedIds, evaluated) }, [
        input,
        element("span", { text: context.t(option.textKey) }),
      ]));
    });
    form.append(fieldset);
  });
  form.append(...resultNodes(ui, state, block));
  const actions = element("div", { className: "assessment-actions" });
  const submit = element("button", { type: "submit", className: "assessment-submit", text: ui.assessmentSubmit, disabled: locked || exhausted });
  actions.append(submit);
  if (state.lastResult && !state.lastResult.passed && !exhausted) {
    actions.append(element("button", { type: "button", className: "assessment-retry", text: ui.assessmentRetry }));
  }
  form.append(actions);
  form.addEventListener("change", () => { submit.disabled = locked || exhausted || !canSubmit(block, selectedAnswers(form, block)); });
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const answers = selectedAnswers(form, block);
    if (!canSubmit(block, answers)) return;
    const result = scoreAssessment(block, answers);
    context.assessments?.submit(block, answers, result);
  });
  actions.querySelector(".assessment-retry")?.addEventListener("click", () => {
    context.assessments?.retry(testId);
  });
  submit.disabled = locked || exhausted || !canSubmit(block, selectedAnswers(form, block));
  return form;
}
