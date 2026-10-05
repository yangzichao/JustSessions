import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import { createGalleryRotation } from "../../../website/scripts/gallery-rotation.js";

const originalWindow = globalThis.window;
const originalDocument = globalThis.document;
afterEach(() => {
  globalThis.window = originalWindow;
  globalThis.document = originalDocument;
});

function createHarness(reducedMotion = false, intervals = [8000]) {
  const timers = new Map();
  const listeners = new Map();
  const preference = { matches: reducedMotion, addEventListener: (_, listener) => listeners.set("motion", listener) };
  const controlStates = [];
  const progressStates = [];
  let clock = 0;
  let timerIdentifier = 0;
  let advanceCount = 0;
  let slideIndex = 0;
  globalThis.document = { hidden: false, addEventListener: (event, listener) => listeners.set(event, listener) };
  globalThis.window = {
    matchMedia: () => preference,
    clearTimeout: (identifier) => timers.delete(identifier),
    setTimeout: (callback, delay) => {
      const identifier = ++timerIdentifier;
      timers.set(identifier, { callback, delay, deadline: clock + delay });
      return identifier;
    },
  };
  const rotation = createGalleryRotation({
    advance: () => { advanceCount++; slideIndex = (slideIndex + 1) % intervals.length; },
    getInterval: () => intervals[slideIndex],
    updateControl: (requested, running) => controlStates.push({ requested, running }),
    updateProgress: (state) => progressStates.push(state),
    now: () => clock,
  });
  return {
    rotation, timers,
    get advanceCount() { return advanceCount; },
    get controlState() { return controlStates.at(-1); },
    get progressState() { return progressStates.at(-1); },
    selectSlide(index) { slideIndex = index; rotation.reset(); },
    elapse(milliseconds) { clock += milliseconds; },
    tick() {
      const [identifier, timer] = timers.entries().next().value;
      timers.delete(identifier);
      clock = Math.max(clock, timer.deadline);
      timer.callback();
    },
    setHidden(hidden) { document.hidden = hidden; listeners.get("visibilitychange")?.(); },
  };
}

test("rotation starts immediately and always keeps exactly one timer", () => {
  const harness = createHarness();
  assert.equal(harness.timers.size, 1);
  assert.deepEqual(harness.controlState, { requested: true, running: true });
  assert.equal([...harness.timers.values()][0].delay, 8000);
  harness.tick();
  assert.equal(harness.advanceCount, 1);
  assert.equal(harness.timers.size, 1);
});

test("background tabs keep advancing without changing playback state", () => {
  const harness = createHarness();
  harness.setHidden(true);
  assert.equal(harness.timers.size, 1);
  harness.tick();
  harness.tick();
  assert.equal(harness.advanceCount, 2);
  assert.deepEqual(harness.controlState, { requested: true, running: true });
  harness.setHidden(false);
  assert.equal(harness.timers.size, 1);
});

test("explicit pause survives visibility changes until explicitly restarted", () => {
  const harness = createHarness();
  harness.rotation.toggle();
  harness.setHidden(true);
  harness.setHidden(false);
  assert.equal(harness.timers.size, 0);
  assert.deepEqual(harness.controlState, { requested: false, running: false });
  harness.rotation.toggle();
  assert.equal(harness.timers.size, 1);
  harness.rotation.toggle();
  assert.equal(harness.timers.size, 0);
});

test("automatic playback starts even when reduced motion is preferred", () => {
  const harness = createHarness(true);
  assert.equal(harness.timers.size, 1);
  harness.tick();
  assert.equal(harness.advanceCount, 1);
  assert.deepEqual(harness.controlState, { requested: true, running: true });
});

test("pause freezes the countdown and resume uses only the remaining time", () => {
  const harness = createHarness();
  harness.elapse(3000);
  harness.rotation.toggle();
  assert.deepEqual(harness.progressState, { elapsed: 3000, duration: 8000, running: false });
  harness.elapse(20000);
  harness.rotation.toggle();
  assert.equal([...harness.timers.values()][0].delay, 5000);
  harness.tick();
  assert.equal(harness.advanceCount, 1);
  assert.deepEqual(harness.progressState, { elapsed: 0, duration: 8000, running: true });
});

test("visibility changes do not restart the running countdown", () => {
  const harness = createHarness();
  const originalTimer = [...harness.timers.entries()][0];
  harness.elapse(2000);
  harness.setHidden(true);
  harness.elapse(2000);
  harness.setHidden(false);
  assert.deepEqual([...harness.timers.entries()][0], originalTimer);
  harness.tick();
  assert.equal(harness.advanceCount, 1);
});

test("selecting another screenshot resets the countdown and keeps playing", () => {
  const harness = createHarness();
  harness.elapse(6000);
  harness.rotation.reset();
  harness.rotation.reset();
  assert.equal(harness.timers.size, 1);
  assert.equal([...harness.timers.values()][0].delay, 8000);
  assert.deepEqual(harness.progressState, { elapsed: 0, duration: 8000, running: true });
  harness.tick();
  assert.equal(harness.advanceCount, 1);
});

test("selecting another screenshot while explicitly paused keeps it paused", () => {
  const harness = createHarness();
  harness.elapse(6000);
  harness.rotation.toggle();
  harness.rotation.reset();
  assert.deepEqual(harness.progressState, { elapsed: 0, duration: 8000, running: false });
  assert.equal(harness.timers.size, 0);
  harness.rotation.toggle();
  assert.equal([...harness.timers.values()][0].delay, 8000);
});

test("automatic transitions give each demo its full countdown", () => {
  const harness = createHarness(false, [8000, 12000, 8000]);
  harness.tick();
  assert.deepEqual(harness.progressState, { elapsed: 0, duration: 12000, running: true });
  assert.equal([...harness.timers.values()][0].delay, 12000);
  harness.tick();
  assert.deepEqual(harness.progressState, { elapsed: 0, duration: 8000, running: true });
  assert.equal(harness.timers.size, 1);
});

test("pausing a longer demo preserves its remaining time and duration", () => {
  const harness = createHarness(false, [12000]);
  harness.elapse(4500);
  harness.rotation.toggle();
  assert.deepEqual(harness.progressState, { elapsed: 4500, duration: 12000, running: false });
  harness.elapse(20000);
  harness.rotation.toggle();
  assert.equal([...harness.timers.values()][0].delay, 7500);
});

test("manual selection updates the duration without resuming an explicit pause", () => {
  const harness = createHarness(false, [8000, 12000]);
  harness.rotation.toggle();
  harness.selectSlide(1);
  assert.deepEqual(harness.progressState, { elapsed: 0, duration: 12000, running: false });
  assert.equal(harness.timers.size, 0);
  harness.rotation.toggle();
  assert.equal([...harness.timers.values()][0].delay, 12000);
  harness.selectSlide(0);
  assert.equal([...harness.timers.values()][0].delay, 8000);
});

test("an invalid demo duration falls back to the default countdown", () => {
  const harness = createHarness(false, [NaN, -1, Infinity]);
  for (let index = 0; index < 3; index++) {
    assert.equal([...harness.timers.values()][0].delay, 8000);
    harness.tick();
  }
});
