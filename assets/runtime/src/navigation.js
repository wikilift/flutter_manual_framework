function sameRoute(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

export function routeUrl(route, language, devMode) {
  const parameters = new URLSearchParams();
  if (route.view === "manual") parameters.set("manualId", route.manualId);
  if (route.view === "collection") parameters.set("collection", route.collectionId);
  if (route.view === "video") {
    parameters.set("video", route.videoId);
    if (route.collectionId) parameters.set("collection", route.collectionId);
  }
  if (language) parameters.set("language", language);
  if (devMode) parameters.set("dev", "1");
  const query = parameters.toString();
  return query ? `?${query}` : window.location.pathname;
}

export function createNavigationController({ initial, initialUrl, onChange, browserHistory, eventTarget, urlFor }) {
  const historyApi = browserHistory ?? window.history;
  const events = eventTarget ?? window;
  const makeUrl = urlFor ?? ((route) => routeUrl(route));
  const stack = [];
  let current = initial;
  let ignoreNextPop = false;

  historyApi.replaceState({ omniRoute: current }, "", initialUrl ?? makeUrl(current));
  events.addEventListener?.("popstate", (event) => {
    const destination = event.state?.omniRoute ?? { view: "library" };
    if (ignoreNextPop && sameRoute(destination, current)) {
      ignoreNextPop = false;
      return;
    }
    if (stack.length && sameRoute(stack.at(-1), destination)) stack.pop();
    else stack.length = 0;
    current = destination;
    onChange(current, { source: "browser" });
  });

  return Object.freeze({
    open(destination, options = {}) {
      if (sameRoute(current, destination)) return current;
      if (!options.replace) stack.push(current);
      current = destination;
      const method = options.replace ? "replaceState" : "pushState";
      historyApi[method]({ omniRoute: current }, "", makeUrl(current));
      onChange(current, { source: "open" });
      return current;
    },
    back() {
      if (!stack.length) {
        if (current.view !== "library") return this.open({ view: "library" }, { replace: true });
        return current;
      }
      current = stack.pop();
      ignoreNextPop = true;
      historyApi.back();
      onChange(current, { source: "back" });
      return current;
    },
    replaceUrl() {
      historyApi.replaceState({ omniRoute: current }, "", makeUrl(current));
    },
    getState: () => ({ current, depth: stack.length }),
  });
}
