// Start automatically; only the playback control can pause rotation.
export function createGalleryRotation({ advance, updateControl, updateProgress = () => {}, interval = 8000, getInterval = () => interval, now = () => performance.now() }) {
  function currentDuration() {
    const value = getInterval();
    return Number.isFinite(value) && value > 0 ? value : interval;
  }
  let requested = true;
  let running = false;
  let duration = currentDuration();
  let remaining = duration;
  let startedAt = 0;
  let timer;

  function refresh() {
    if (running) remaining = Math.max(0, remaining - (now() - startedAt));
    window.clearTimeout(timer);
    running = requested;
    startedAt = now();
    updateControl(requested, running);
    updateProgress({ elapsed: duration - remaining, duration, running });
    if (running) {
      timer = window.setTimeout(() => {
        running = false;
        advance();
        duration = currentDuration();
        remaining = duration;
        refresh();
      }, remaining);
    }
  }

  refresh();

  return {
    toggle() { requested = !requested; refresh(); },
    reset() { running = false; duration = currentDuration(); remaining = duration; refresh(); },
  };
}
