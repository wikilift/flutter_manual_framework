export function createComponentRegistry() {
  const renderers = new Map();
  return Object.freeze({
    register(type, renderer) {
      if (renderers.has(type)) throw new Error(`Componente ya registrado: ${type}`);
      renderers.set(type, renderer);
    },
    render(block, context) {
      const renderer = renderers.get(block.type);
      if (!renderer) {
        console.error(`[renderer] Componente desconocido: ${block.type}`, block);
        return context.devMode ? context.technicalError(`Componente no compatible: ${block.type}`) : document.createComment(`Componente omitido: ${block.type}`);
      }
      try {
        return renderer(block, context);
      } catch (error) {
        console.error(`[renderer] Error en ${block.type}`, error);
        return context.devMode ? context.technicalError(`No se pudo renderizar el componente ${block.type}`) : document.createComment(`Error de componente: ${block.type}`);
      }
    },
    has: (type) => renderers.has(type),
  });
}
