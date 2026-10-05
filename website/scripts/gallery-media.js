// The gallery's existing play/pause control also controls its active demo clip.
export function createGalleryMedia(slides) {
  let selectedIndex = 0;
  let playing = true;

  function updatePlayback() {
    slides.forEach((slide, index) => {
      for (const video of slide.querySelectorAll("video[data-gallery-video]")) {
        if (!playing || index !== selectedIndex) {
          video.pause();
        } else if (video.paused) {
          // A browser that blocks autoplay keeps the poster visible.
          video.play()?.catch(() => {});
        }
      }
    });
  }

  return {
    select(index) {
      if (index !== selectedIndex) {
        for (const video of slides[index].querySelectorAll("video[data-gallery-video]")) video.currentTime = 0;
      }
      selectedIndex = index;
      updatePlayback();
    },
    setPlaying(requested) {
      playing = requested;
      updatePlayback();
    },
  };
}
