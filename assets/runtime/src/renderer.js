import { clear, element, technicalError } from "./dom.js";
import { createComponentRegistry } from "./component-registry.js";
import { renderCover } from "./components/cover.js";
import { renderParagraph } from "./components/paragraph.js";
import { renderNote } from "./components/note.js";
import { renderWarning } from "./components/warning.js";
import { renderImage } from "./components/image.js";
import { renderImageGrid } from "./components/image-grid.js";
import { renderScreenshotGallery } from "./components/screenshot-gallery.js";
import { renderAnnotatedImage } from "./components/annotated-image.js";
import { renderVideo } from "./components/video.js";
import { renderSteps } from "./components/steps.js";
import { renderList } from "./components/list.js";
import { renderTable } from "./components/table.js";
import { renderFlowchart } from "./components/flowchart.js";
import { renderElectricalSchematic } from "./components/electrical-schematic.js";
import { optionalTranslationText } from "./components/shared.js";

export function defaultRegistry() {
  const registry = createComponentRegistry();
  registry.register("cover", renderCover);
  registry.register("paragraph", renderParagraph);
  registry.register("note", renderNote);
  registry.register("warning", renderWarning);
  registry.register("image", renderImage);
  registry.register("image-grid", renderImageGrid);
  registry.register("screenshot-gallery", renderScreenshotGallery);
  registry.register("annotated-image", renderAnnotatedImage);
  registry.register("video", renderVideo);
  registry.register("steps", renderSteps);
  registry.register("list", renderList);
  registry.register("table", renderTable);
  registry.register("flowchart", renderFlowchart);
  registry.register("electrical-schematic", renderElectricalSchematic);
  return registry;
}

export function renderManual(container, toc, manual, context, registry = defaultRegistry()) {
  clear(container);
  clear(toc);
  manual.sections.forEach((section, index) => {
    if (context.devMode) globalThis.window?.__omniPreviewTrace?.("section:render", { id: section.id, type: section.type, blocks: section.type === "section" ? (section.blocks ?? []).length : 0 });
    const isCover = section.type === "cover";
    const node = element("section", { id: section.id, className: isCover ? "manual-section cover" : "manual-section", dataset: { sectionId: section.id } });
    if (isCover) node.append(registry.render(section, { ...context, technicalError }));
    else {
      node.append(element("p", { className: "section-number", text: String(index).padStart(2, "0") }));
      node.append(element("h2", { text: context.t(section.titleKey) }));
      const description = optionalTranslationText(context, section.descriptionKey);
      if (description) node.append(element("p", { className: "section-description", text: description }));
      const body = element("div", { className: "section-body" });
      (section.blocks ?? []).forEach((block, blockIndex) => {
        if (context.devMode) globalThis.window?.__omniPreviewTrace?.("block:render", { sectionId: section.id, blockIndex, type: block.type });
        body.append(registry.render(block, { ...context, sectionId: section.id, blockIndex, technicalError }));
      });
      node.append(body);
    }
    container.append(node);
    const link = element("a", { href: `#${section.id}`, text: context.t(section.titleKey), dataset: { sectionId: section.id } });
    toc.append(element("div", { className: "toc-item" }, [link]));
  });
}
