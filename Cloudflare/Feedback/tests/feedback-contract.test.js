import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import * as contract from "../../../website/scripts/feedback/feedback-contract.js";

const repositoryURL = new URL("../../../", import.meta.url);

test("the app sends feedback within the limits the Worker accepts", () => {
  const swiftLimits = readFileSync(new URL("Sources/JustSessions/Models/App/Feedback/Submission/FeedbackLimits.swift", repositoryURL), "utf8");
  const swiftValue = (name) => Number(swiftLimits.match(new RegExp(`static let ${name} = (\\d+)`))?.[1]);
  assert.equal(swiftValue("maximumMessageLength"), contract.maximumMessageLength);
  assert.equal(swiftValue("maximumContactLength"), contract.maximumContactLength);
});

test("the app posts to the Worker and loads Turnstile from the published verification page", () => {
  const appLinks = readFileSync(new URL("Sources/JustSessions/Models/App/AppLinks.swift", repositoryURL), "utf8");
  assert.ok(appLinks.includes(`URL(string: "${contract.feedbackEndpoint}")`), "AppLinks.feedbackEndpointURL differs");
  assert.ok(appLinks.includes(`"app-feedback-verification.html"`), "AppLinks.feedbackVerificationPageURL differs");
  assert.equal(new URL(contract.feedbackEndpoint).pathname, "/feedback");
});

test("the database refuses what the Worker would refuse", () => {
  const migration = readFileSync(new URL("../migrations/0001_create_feedback.sql", import.meta.url), "utf8");
  assert.match(migration, new RegExp(`length\\(message\\) BETWEEN 1 AND ${contract.maximumMessageLength}`));
  assert.match(migration, new RegExp(`length\\(contact\\) <= ${contract.maximumContactLength}`));
  assert.match(migration, new RegExp(`source IN \\(${[...contract.feedbackSources].map((source) => `'${source}'`).join(", ")}\\)`));
});
