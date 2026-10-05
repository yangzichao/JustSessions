// Start automatically; only the playback control can pause rotation.
export function createGalleryRotation({ advance, updateControl, updateProgress = () => {}, interval = 8000, now = () => performance.now() }) {
  let requested = true;
  let running = false;
  let remaining = interval;
  let startedAt = 0;
  let timer;

  function refresh() {
    if (running) remaining = Math.max(0, remaining - (now() - startedAt));
    window.clearTimeout(timer);
    running = requested;
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

  refresh();

  return {
    toggle() { requested = !requested; refresh(); },
    reset() { running = false; remaining = interval; refresh(); },
  };
}
