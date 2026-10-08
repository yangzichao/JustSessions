import { createGalleryRotation } from "./gallery-rotation.js";
import { createGalleryProgress } from "./gallery-progress.js";
import { createGalleryMedia } from "./gallery-media.js";

for (const gallery of document.querySelectorAll("[data-screenshot-gallery]")) {
  const track = gallery.querySelector("[data-gallery-track]");
  const slides = [...track.querySelectorAll(".gallery-slide")];
  const pageButtons = [...gallery.querySelectorAll("[data-gallery-page]")];
  const rotationButton = gallery.querySelector("[data-gallery-rotation]");
  const status = gallery.querySelector("[data-gallery-status]");
  const motionPreference = window.matchMedia("(prefers-reduced-motion: reduce)");
  const media = createGalleryMedia(slides);
  let currentIndex = 0;
  let scrollTimer;

  function updateSelection(index) {
    currentIndex = index;
    pageButtons.forEach((button, buttonIndex) => {
      if (buttonIndex === index) button.setAttribute("aria-current", "true");
      else button.removeAttribute("aria-current");
    });
    status.textContent = slides[index].getAttribute("aria-label");
    slides.forEach((slide, slideIndex) => {
      slide.setAttribute("aria-hidden", slideIndex === index ? "false" : "true");
      // Inactive screenshots remain available to touch scrolling but not tab navigation.
      for (const link of slide.querySelectorAll("a")) link.tabIndex = slideIndex === index ? 0 : -1;
    });
    media.select(index);
  }

  function showSlide(index, animate = true) {
    const targetIndex = (index + slides.length) % slides.length;
    const isAdjacent = Math.abs(targetIndex - currentIndex) === 1;
    track.scrollTo({
      left: slides[targetIndex].offsetLeft,
      behavior: animate && isAdjacent && !motionPreference.matches ? "smooth" : "instant",
    });
    updateSelection(targetIndex);
  }

  updateSelection(0);
  const rotation = createGalleryRotation({
    advance: () => showSlide(currentIndex + 1),
    getInterval: () => Number(slides[currentIndex].dataset.galleryDuration) || 8000,
    updateProgress: createGalleryProgress(pageButtons),
    updateControl: (requested, running) => {
      media.setPlaying(requested);
      rotationButton.setAttribute("aria-label", requested ? "Pause automatic slideshow" : "Start automatic slideshow");
      rotationButton.firstElementChild.textContent = requested ? "Ⅱ" : "▶";
      status.setAttribute("aria-live", running ? "off" : "polite");
    },
  });

  function manuallyShow(index) {
    showSlide(index);
    rotation.reset();
  }

  gallery.querySelector("[data-gallery-previous]").addEventListener("click", () => manuallyShow(currentIndex - 1));
  gallery.querySelector("[data-gallery-next]").addEventListener("click", () => manuallyShow(currentIndex + 1));
  pageButtons.forEach((button, index) => button.addEventListener("click", () => manuallyShow(index)));
  rotationButton.addEventListener("click", () => rotation.toggle());
  track.addEventListener("keydown", (event) => {
    if (event.target !== track || !["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    event.preventDefault();
    const targetIndex = event.key === "Home" ? 0 : event.key === "End" ? slides.length - 1 : currentIndex + (event.key === "ArrowRight" ? 1 : -1);
    manuallyShow(targetIndex);
  });
  track.addEventListener("scroll", () => {
    window.clearTimeout(scrollTimer);
    scrollTimer = window.setTimeout(() => {
      const nearestIndex = slides.reduce((nearest, slide, index) =>
        Math.abs(slide.offsetLeft - track.scrollLeft) < Math.abs(slides[nearest].offsetLeft - track.scrollLeft) ? index : nearest, 0);
      if (nearestIndex !== currentIndex) {
        updateSelection(nearestIndex);
        rotation.reset();
      }
    }, 150);
  }, { passive: true });

  function showLinkedSlide() {
    const linkedIndex = slides.findIndex((slide) => `#${slide.id}` === window.location.hash);
    if (linkedIndex >= 0) {
      showSlide(linkedIndex, false);
      rotation.reset();
    }
  }
  window.addEventListener("hashchange", showLinkedSlide);
  const resizeObserver = new ResizeObserver(() => showSlide(currentIndex, false));
  resizeObserver.observe(track);
  gallery.querySelector("[data-gallery-controls]").hidden = false;
  showLinkedSlide();
}
