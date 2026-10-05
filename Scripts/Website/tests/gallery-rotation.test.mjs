import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import { createGalleryRotation } from "../../../website/scripts/gallery-rotation.js";

const originalWindow = globalThis.window;
const originalDocument = globalThis.document;
afterEach(() => {
  globalThis.window = originalWindow;
  globalThis.document = originalDocument;
});

function createHarness(reducedMotion = false) {
  const timers = new Map();
  const listeners = new Map();
  const preference = { matches: reducedMotion, addEventListener: (_, listener) => listeners.set("motion", listener) };
  const controlStates = [];
  const progressStates = [];
  let clock = 0;
  let timerIdentifier = 0;
  let advanceCount = 0;
  globalThis.document = { hidden: false, addEventListener: (event, listener) => listeners.set(event, listener) };
  globalThis.window = {
    matchMedia: () => preference,
    clearTimeout: (identifier) => timers.delete(identifier),
    setTimeout: (callback, delay) => {
      const identifier = ++timerIdentifier;
      timers.set(identifier, { callback, delay });
      return identifier;
    },
  };
  const rotation = createGalleryRotation({
    advance: () => advanceCount++,
    updateControl: (requested, running) => controlStates.push({ requested, running }),
    updateProgress: (state) => progressStates.push(state),
    now: () => clock,
  });
  return {
    rotation, timers,
    get advanceCount() { return advanceCount; },
    get controlState() { return controlStates.at(-1); },
    get progressState() { return progressStates.at(-1); },
    elapse(milliseconds) { clock += milliseconds; },
    tick() {
      const [identifier, timer] = timers.entries().next().value;
      timers.delete(identifier);
      clock += timer.delay;
      timer.callback();
    },
    setHidden(hidden) { document.hidden = hidden; listeners.get("visibilitychange")(); },
  };
}

test("rotation waits until visible and always keeps exactly one timer", () => {
  const harness = createHarness();
  assert.equal(harness.timers.size, 0);
  harness.rotation.setVisible(true);
  harness.rotation.setVisible(true);
  assert.equal(harness.timers.size, 1);
  assert.equal([...harness.timers.values()][0].delay, 8000);
  harness.tick();
  assert.equal(harness.advanceCount, 1);
  assert.equal(harness.timers.size, 1);
});

test("background tabs and leaving the viewport suspend automatic rotation", () => {
  const harness = createHarness();
  harness.rotation.setVisible(true);
  harness.setHidden(true);
  assert.equal(harness.timers.size, 0);
  harness.setHidden(false);
  assert.equal(harness.timers.size, 1);
  harness.rotation.setVisible(false);
  assert.equal(harness.timers.size, 0);
});

test("manual stop survives visibility changes until explicitly restarted", () => {
  const harness = createHarness();
  harness.rotation.setVisible(true);
  harness.rotation.stop();
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
  harness.rotation.setVisible(true);
  assert.equal(harness.timers.size, 1);
  harness.tick();
  assert.equal(harness.advanceCount, 1);
  assert.deepEqual(harness.controlState, { requested: true, running: true });
});

test("pause freezes the countdown and resume uses only the remaining time", () => {
  const harness = createHarness();
  harness.rotation.setVisible(true);
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

test("visibility changes preserve progress without restarting the countdown", () => {
  const harness = createHarness();
  harness.rotation.setVisible(true);
  harness.elapse(2000);
  harness.rotation.setVisible(true);
  assert.equal([...harness.timers.values()][0].delay, 6000);
  harness.setHidden(true);
  harness.elapse(20000);
  harness.setHidden(false);
  assert.equal([...harness.timers.values()][0].delay, 6000);
  harness.rotation.setVisible(false);
  harness.elapse(20000);
  harness.rotation.setVisible(true);
  assert.equal([...harness.timers.values()][0].delay, 6000);
});

test("selecting a different screenshot starts its full countdown when playback resumes", () => {
  const harness = createHarness();
  harness.rotation.setVisible(true);
  harness.elapse(6000);
  harness.rotation.stop();
  harness.rotation.reset();
  assert.deepEqual(harness.progressState, { elapsed: 0, duration: 8000, running: false });
  assert.equal(harness.timers.size, 0);
  harness.rotation.toggle();
  assert.equal([...harness.timers.values()][0].delay, 8000);
});
