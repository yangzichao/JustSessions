// Start automatically and keep one timer while the gallery is visible.
export function createGalleryRotation({ advance, updateControl, updateProgress = () => {}, interval = 8000, now = () => performance.now() }) {
  let requested = true;
  let visible = false;
  let running = false;
  let remaining = interval;
  let startedAt = 0;
  let timer;

  function refresh() {
    if (running) remaining = Math.max(0, remaining - (now() - startedAt));
    window.clearTimeout(timer);
    running = requested && visible && !document.hidden;
    startedAt = now();
    updateControl(requested, running);
    updateProgress({ elapsed: interval - remaining, duration: interval, running });
    if (running) {
      timer = window.setTimeout(() => {
        running = false;
        remaining = interval;
        advance();
        refresh();
      }, remaining);
    }
  }

  document.addEventListener("visibilitychange", refresh);

  return {
    stop() { requested = false; refresh(); },
    toggle() { requested = !requested; refresh(); },
    setVisible(value) { visible = value; refresh(); },
    reset() { running = false; remaining = interval; refresh(); },
  };
}
