// Render the countdown from the same clock that advances the screenshots.
export function createGalleryProgress(pageButtons) {
  const fills = pageButtons.map((button) => button.querySelector("[data-gallery-progress-fill]"));
  let animation;

  return ({ elapsed, duration, running }) => {
    animation?.cancel();
    const currentIndex = pageButtons.findIndex((button) => button.getAttribute("aria-current") === "true");
    fills.forEach((fill, index) => {
      const progress = index < currentIndex ? 1 : index === currentIndex ? elapsed / duration : 0;
      fill.style.transform = `scaleX(${progress})`;
    });
    if (running && currentIndex >= 0 && elapsed < duration) {
      animation = fills[currentIndex].animate([
        { transform: `scaleX(${elapsed / duration})` },
        { transform: "scaleX(1)" },
      ], { duration: duration - elapsed, easing: "linear", fill: "forwards" });
    }
  };
}
