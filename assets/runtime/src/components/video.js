import { element } from "../dom.js";
import { optionalTranslationText } from "./shared.js";

const LOCAL_HTTP_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]", "::1"]);

function videoSource(block) {
  if (block.sourceType === "api") {
    return {
      type: "api",
      endpoint: block.endpoint,
      fileName: block.fileName,
      mimeType: block.mimeType,
      allowUnavailable: block.allowUnavailable,
    };
  }
  if (block.source && typeof block.source === "object") return block.source;
  return { type: "asset", src: block.src, mimeType: block.mimeType };
}

function isAllowedRemoteUrl(value) {
  try {
    const url = new URL(String(value));
    if (url.username || url.password) return false;
    if (url.protocol === "https:") return true;
    if (url.protocol === "http:") return LOCAL_HTTP_HOSTS.has(url.hostname);
    return false;
  } catch {
    return false;
  }
}

function iframeUrl(source) {
  if (source.type === "youtube" && /^[A-Za-z0-9_-]{11}$/.test(source.videoId ?? "")) return `https://www.youtube-nocookie.com/embed/${source.videoId}`;
  if (source.type === "embed" && isAllowedRemoteUrl(source.url)) return source.url;
  return null;
}

function apiVideoUrl(source, context) {
  if (source.type !== "api" || typeof source.endpoint !== "string" || !source.endpoint) return "";
  const base = context.apiBaseUrl ?? context.publicApiBaseUrl;
  if (typeof base !== "string" || !base) return "";
  try {
    const endpoint = source.endpoint.trim();
    if (!endpoint.startsWith("/")) return "";
    return new URL(endpoint, base).href;
  } catch {
    return "";
  }
}

function videoUnavailableMessage(context) {
  if (typeof navigator !== "undefined" && navigator.onLine === false) return context.ui.videoConnectionUnavailable ?? "Conexión no disponible";
  return context.ui.videoUnavailable ?? "No se ha podido cargar el vídeo";
}

function clearVideoSource(video) {
  if (typeof video.removeAttribute === "function") video.removeAttribute("src");
  else if (video.attributes) delete video.attributes.src;
  video.src = "";
  video.load?.();
}

function renderApiVideo(block, source, context, caption) {
  const poster = block.poster ? context.assetUrl(block.poster) ?? undefined : undefined;
  const video = element("video", {
    controls: block.controls !== false,
    autoplay: false,
    muted: block.muted === true,
    loop: block.loop === true,
    preload: "none",
    playsInline: true,
    poster,
  });
  video.append(document.createTextNode(context.ui.videoUnsupported));

  const playButton = element("button", {
    type: "button",
    className: "video-play-button",
    text: context.ui.videoPlay ?? "Reproducir vídeo",
  });
  const fallback = element("p", { className: "media-fallback video-api-status", text: "", hidden: true });
  let timeoutId = null;

  const clearTimeoutIfNeeded = () => {
    if (timeoutId !== null) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
  };
  const setLoading = (loading) => {
    playButton.hidden = loading;
    fallback.hidden = true;
  };
  const showRetry = (message) => {
    clearTimeoutIfNeeded();
    clearVideoSource(video);
    playButton.hidden = false;
    fallback.textContent = message;
    fallback.hidden = false;
  };
  const start = () => {
    const url = apiVideoUrl(source, context);
    if (!url) {
      showRetry(videoUnavailableMessage(context));
      return;
    }
    setLoading(true);
    video.setAttribute("src", url);
    video.src = url;
    video.load?.();
    timeoutId = setTimeout(() => showRetry(videoUnavailableMessage(context)), 15000);
    try {
      const result = video.play?.();
      if (result && typeof result.catch === "function") result.catch(() => showRetry(videoUnavailableMessage(context)));
    } catch {
      showRetry(videoUnavailableMessage(context));
    }
  };

  playButton.addEventListener("click", start);
  video.addEventListener("loadstart", () => setLoading(true));
  video.addEventListener("loadedmetadata", clearTimeoutIfNeeded);
  video.addEventListener("canplay", clearTimeoutIfNeeded);
  video.addEventListener("playing", () => {
    clearTimeoutIfNeeded();
    playButton.hidden = true;
    fallback.hidden = true;
  });
  video.addEventListener("waiting", () => { fallback.hidden = true; });
  video.addEventListener("stalled", () => showRetry(videoUnavailableMessage(context)));
  video.addEventListener("error", () => showRetry(videoUnavailableMessage(context)));
  video.addEventListener("abort", () => showRetry(videoUnavailableMessage(context)));

  return element("figure", { className: "video-component video-api technical-width" }, [
    element("div", { className: "video-api-shell" }, [video, playButton]),
    fallback,
    caption ? element("figcaption", { text: caption }) : null,
  ]);
}

export function renderVideo(block, context) {
  const caption = optionalTranslationText(context, block.captionKey);
  const source = videoSource(block);
  if (document.body.classList.contains("print-mode")) {
    const poster = block.poster ? context.assetUrl(block.poster) : null;
    const image = poster ? element("img", { src: poster, alt: caption, loading: "eager" }) : null;
    const fallback = source.type === "youtube" || source.type === "embed" || source.type === "api" ? "Vídeo remoto disponible en la versión digital." : context.ui.videoUnavailable;
    return element("figure", { className: "video-component technical-width" }, [
      image ?? element("div", { className: "video-print-fallback", text: fallback }),
      element("figcaption", { text: caption || fallback }),
    ]);
  }
  if (source.type === "youtube" || source.type === "embed") {
    const url = iframeUrl(source);
    const fallback = element("p", { className: "media-fallback", text: context.ui.videoUnavailable, hidden: Boolean(url) });
    const frame = url ? element("iframe", { src: url, title: caption || "Vídeo", loading: "lazy", allow: "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share", allowFullscreen: true }) : null;
    return element("figure", { className: "video-component video-embed technical-width" }, [frame, fallback, caption ? element("figcaption", { text: caption }) : null]);
  }
  if (source.type === "api") return renderApiVideo(block, source, context, caption);
  const src = source.type === "url"
      ? (isAllowedRemoteUrl(source.url) ? source.url : "")
      : (source.src ? context.assetUrl(source.src) : "");
  const video = element("video", {
    controls: block.controls !== false,
    autoplay: block.autoplay === true,
    muted: block.muted === true || block.autoplay === true,
    loop: block.loop === true,
    preload: "metadata",
    playsInline: true,
    poster: block.poster ? context.assetUrl(block.poster) ?? undefined : undefined,
  });
  const mediaSource = element("source", { src, type: source.mimeType ?? "video/mp4" });
  video.append(mediaSource);
  video.append(document.createTextNode(context.ui.videoUnsupported));
  const fallback = element("p", { className: "media-fallback", text: context.ui.videoUnavailable, hidden: true });
  const showFallback = () => {
    video.hidden = true;
    fallback.hidden = false;
  };
  video.addEventListener("error", showFallback, { once: true });
  mediaSource.addEventListener("error", showFallback, { once: true });
  if (!src) showFallback();
  return element("figure", { className: "video-component technical-width" }, [video, fallback, caption ? element("figcaption", { text: caption }) : null]);
}
