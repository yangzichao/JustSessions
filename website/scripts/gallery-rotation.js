// Keep one timer, and reset its delay whenever visibility or interaction changes.
export function createGalleryRotation({ advance, updateControl, interval = 8000 }) {
  const motionPreference = window.matchMedia("(prefers-reduced-motion: reduce)");
  let requested = !motionPreference.matches;
  let visible = false;
  let hovered = false;
  let timer;

  function refresh() {
    window.clearTimeout(timer);
    const running = requested && visible && !hovered && !document.hidden;
    updateControl(requested, running);
    if (running) {
      timer = window.setTimeout(() => {
        advance();
        refresh();
      }, interval);
    }
  }

  document.addEventListener("visibilitychange", refresh);
  motionPreference.addEventListener("change", () => {
    if (motionPreference.matches) requested = false;
    refresh();
  });

  return {
    stop() { requested = false; refresh(); },
    toggle() { requested = !requested; refresh(); },
    setVisible(value) { visible = value; refresh(); },
    setHovered(value) { hovered = value; refresh(); },
  };
}
