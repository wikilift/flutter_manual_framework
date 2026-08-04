const listeners = new Set();
let state = Object.freeze({
  view: "library",
  devMode: false,
  library: null,
  manifest: null,
  manual: null,
  language: null,
  manualId: null,
  collectionId: null,
  videoId: null,
  sectionId: null,
  section: null,
  drawerOpen: false,
  lightboxOpen: false,
});

export function getState() {
  return state;
}

export function setState(patch) {
  state = Object.freeze({ ...state, ...patch });
  listeners.forEach((listener) => listener(state));
  return state;
}

export function subscribe(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}
