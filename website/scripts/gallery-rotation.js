// Start automatically and keep one timer while the gallery is visible.
export function createGalleryRotation({ advance, updateControl, interval = 8000 }) {
  let requested = true;
  let visible = false;
  let timer;

  function refresh() {
    window.clearTimeout(timer);
    const running = requested && visible && !document.hidden;
    updateControl(requested, running);
    if (running) {
      timer = window.setTimeout(() => {
        advance();
        refresh();
      }, interval);
    }
  }

  document.addEventListener("visibilitychange", refresh);

  return {
    stop() { requested = false; refresh(); },
    toggle() { requested = !requested; refresh(); },
    setVisible(value) { visible = value; refresh(); },
  };
}
