import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { readAppVersions } from "../../../website/scripts/feedback/app-versions.js";
import * as contract from "../../../website/scripts/feedback/feedback-contract.js";

const repositoryURL = new URL("../../../", import.meta.url);

test("the app opens the Guide's form with the versions the form reads from its address", () => {
  const appLinks = readFileSync(new URL("Sources/JustSessions/Models/App/AppLinks.swift", repositoryURL), "utf8");
  const feedbackLinks = readFileSync(new URL("Sources/JustSessions/Models/App/Feedback/FeedbackLinks.swift", repositoryURL), "utf8");
  assert.ok(appLinks.includes(`userGuideFeedbackURL = userGuideSection("feedback")`), "AppLinks.userGuideFeedbackURL differs");
  for (const name of ["appVersion", "macOSVersion"]) {
    assert.ok(feedbackLinks.includes(`URLQueryItem(name: "${name}"`), `FeedbackLinks.formURL does not send ${name}`);
  }
  assert.deepEqual(readAppVersions("?appVersion=1.1.0%20(98)&macOSVersion=26.5"), { appVersion: "1.1.0 (98)", macOSVersion: "26.5" });
  assert.equal(new URL(contract.feedbackEndpoint).pathname, "/feedback");
});

test("the database refuses what the Worker would refuse", () => {
  const migration = readFileSync(new URL("../migrations/0001_create_feedback.sql", import.meta.url), "utf8");
  assert.match(migration, new RegExp(`length\\(message\\) BETWEEN 1 AND ${contract.maximumMessageLength}`));
  assert.match(migration, new RegExp(`length\\(contact\\) <= ${contract.maximumContactLength}`));
  assert.match(migration, new RegExp(`source IN \\(${[...contract.feedbackSources].map((source) => `'${source}'`).join(", ")}\\)`));
});
