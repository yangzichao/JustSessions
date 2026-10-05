import test from "node:test";
import assert from "node:assert/strict";
import { createGalleryMedia } from "../../../website/scripts/gallery-media.js";

function createVideo() {
  return {
    paused: true,
    currentTime: 3,
    playCount: 0,
    pauseCount: 0,
    play() { this.paused = false; this.playCount += 1; return Promise.resolve(); },
    pause() { this.paused = true; this.pauseCount += 1; },
  };
}

function slideWith(...videos) {
  return { querySelectorAll: () => videos };
}

test("only the selected slide plays its demo", () => {
  const first = createVideo();
  const second = createVideo();
  const media = createGalleryMedia([slideWith(first), slideWith(second)]);
  media.select(0);
  assert.equal(first.paused, false);
  assert.equal(second.paused, true);
});

test("the gallery pause control freezes the clip and resumes the same position", () => {
  const video = createVideo();
  const media = createGalleryMedia([slideWith(video)]);
  media.select(0);
  media.setPlaying(false);
  assert.equal(video.paused, true);
  assert.equal(video.currentTime, 3);
  media.setPlaying(true);
  assert.equal(video.paused, false);
  assert.equal(video.currentTime, 3);
});

test("a newly selected demo restarts and the previous one stops", () => {
  const first = createVideo();
  const second = createVideo();
  const media = createGalleryMedia([slideWith(first), slideWith(second)]);
  media.select(0);
  media.select(1);
  assert.equal(first.paused, true);
  assert.equal(second.paused, false);
  assert.equal(second.currentTime, 0);
});

test("selection while explicitly paused never starts a demo", () => {
  const video = createVideo();
  const media = createGalleryMedia([slideWith(), slideWith(video)]);
  media.setPlaying(false);
  media.select(1);
  assert.equal(video.playCount, 0);
  assert.equal(video.currentTime, 0);
});

test("reselecting the current slide preserves its playback position", () => {
  const video = createVideo();
  const media = createGalleryMedia([slideWith(video)]);
  media.select(0);
  media.select(0);
  assert.equal(video.currentTime, 3);
  assert.equal(video.playCount, 1);
});

test("blocked autoplay and slides without video do not break gallery controls", async () => {
  const video = createVideo();
  video.play = () => Promise.reject(new Error("Autoplay blocked"));
  const media = createGalleryMedia([slideWith(video), slideWith()]);
  media.select(0);
  await Promise.resolve();
  media.select(1);
  media.setPlaying(false);
  assert.equal(video.paused, true);
});
