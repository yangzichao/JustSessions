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
  });
  return {
    rotation, timers,
    get advanceCount() { return advanceCount; },
    get controlState() { return controlStates.at(-1); },
    tick() {
      const [identifier, timer] = timers.entries().next().value;
      timers.delete(identifier);
      timer.callback();
    },
    setHidden(hidden) { document.hidden = hidden; listeners.get("visibilitychange")(); },
    setReducedMotion(matches) { preference.matches = matches; listeners.get("motion")(); },
  };
}

test("rotation waits until visible and always keeps exactly one timer", () => {
  const harness = createHarness();
  assert.equal(harness.timers.size, 0);
  harness.rotation.setVisible(true);
  harness.rotation.setVisible(true);
  assert.equal(harness.timers.size, 1);
  assert.equal([...harness.timers.values()][0].delay, 6500);
  harness.tick();
  assert.equal(harness.advanceCount, 1);
  assert.equal(harness.timers.size, 1);
});

test("hover, background tabs, and leaving the viewport suspend automatic rotation", () => {
  const harness = createHarness();
  harness.rotation.setVisible(true);
  harness.rotation.setHovered(true);
  assert.equal(harness.timers.size, 0);
  assert.deepEqual(harness.controlState, { requested: true, running: false });
  harness.rotation.setHovered(false);
  assert.equal(harness.timers.size, 1);
  harness.setHidden(true);
  assert.equal(harness.timers.size, 0);
  harness.setHidden(false);
  assert.equal(harness.timers.size, 1);
  harness.rotation.setVisible(false);
  assert.equal(harness.timers.size, 0);
});

test("manual stop survives visibility and hover changes until explicitly restarted", () => {
  const harness = createHarness();
  harness.rotation.setVisible(true);
  harness.rotation.stop();
  harness.rotation.setHovered(true);
  harness.rotation.setHovered(false);
  harness.setHidden(true);
  harness.setHidden(false);
  assert.equal(harness.timers.size, 0);
  assert.deepEqual(harness.controlState, { requested: false, running: false });
  harness.rotation.toggle();
  assert.equal(harness.timers.size, 1);
  harness.rotation.toggle();
  assert.equal(harness.timers.size, 0);
});

test("reduced motion disables initial playback and cancels an active timer when enabled", () => {
  const harness = createHarness(true);
  harness.rotation.setVisible(true);
  assert.equal(harness.timers.size, 0);
  harness.rotation.toggle();
  assert.equal(harness.timers.size, 1);
  harness.setReducedMotion(true);
  assert.equal(harness.timers.size, 0);
  harness.setReducedMotion(false);
  assert.equal(harness.timers.size, 0);
});
