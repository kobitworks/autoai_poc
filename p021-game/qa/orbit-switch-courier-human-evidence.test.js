#!/usr/bin/env node
"use strict";

// Synthetic contract tests only: no device is accessed, and no human PASS is inferred.
const test = require("node:test");
const assert = require("node:assert/strict");
const { inspect, blank, GATES } = require("./orbit-switch-courier-human-evidence.js");

const validEvidence = () => {
  const d = blank();
  d.build.sourceCommit = "a".repeat(40);
  d.build.actionsRunId = "38697001992";
  d.build.liveByteGate = "PASS_LIVE_BYTES";
  d.build.testedBuildMatchesVerifiedBuild = true;
  d.build.verifiedAtJst = "2026-10-15 16:10:55 JST";
  d.build.verificationEvidence = "Mock byte-for-byte match in fixture only";
  d.device = { model: "Synthetic iPad", os: "Test OS", browser: "Mock browser",
    testerAlias: "synthetic-test", testedAtJst: "2026-10-15 17:40:00 JST" };
  for (const [key] of GATES) {
    Object.assign(d.observations[key], {
      status: "PASS", evidence: "SYNTHETIC TEST RECORD, NOT DEVICE DATA",
      observedAtJst: "2026-10-15 17:41:00 JST", observedBy: "human"
    });
  }
  Object.assign(d.observations.first30s, {
    firstActionSeconds: 18, firstCorrectActionObserved: true, goalUnderstoodUnprompted: true
  });
  d.observations.misTaps.count = 0;
  Object.assign(d.observations.nightAce, {
    nightDeliveries: 3, aceDeliveries: 6, naturalInput: true, stateInjected: false
  });
  d.observations.warningRecognition.recognitionSeconds = 2;
  d.observations.resultRetryBest.bestPersisted = true;
  for (const k of ["speaker", "headphone"]) Object.assign(d.observations[k], {
    soundOnAudible: true, soundOffSilent: true, soundOnRestored: true
  });
  Object.assign(d.observations.fpsHeat, {
    playMinutes: 3.5,
    responsivenessAssessment: "Responsive on synthetic device, no slowdown",
    heatAssessment: "Synthetic device warmth stayed within expected range"
  });
  d.observations.physicalRotation.orientations = ["portrait", "landscape"];
  return d;
};

test("empty v1.1 template is on hold, never a pass", () => {
  const r = inspect(blank());
  assert.equal(r.verdict, "HOLD_DEVICE_DETAILS");
  assert.equal(r.eligibleForScoring, false);
  assert.equal(r.untested.length, 9);
});

test("fully populated synthetic record is structurally ready only", () => {
  const r = inspect(validEvidence());
  assert.equal(r.verdict, "READY_FOR_INDEPENDENT_SCORING");
  assert.equal(r.eligibleForScoring, true);
  assert.match(r.note, /Evidence fields are not authenticated/);
});

test("old schema version is rejected; template must be regenerated", () => {
  const d = validEvidence(); d.schemaVersion = "1.0";
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
});

test("calendar-invalid device timestamps cannot pass", () => {
  const d = validEvidence(); d.device.testedAtJst = "2026-02-30 17:41:00 JST";
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
});

test("out-of-range verified time cannot be PASS-ready", () => {
  const d = validEvidence(); d.build.verifiedAtJst = "2026-10-15 25:61:99 JST";
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
});

test("NIGHT / ACE counts alone do not prove natural input", () => {
  const d = validEvidence(); d.observations.nightAce.naturalInput = null;
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
  d.observations.nightAce.naturalInput = true;
  d.observations.nightAce.stateInjected = true;
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
});

test("unassisted correct first action and goal understanding are required", () => {
  const d = validEvidence(); d.observations.first30s.goalUnderstoodUnprompted = null;
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
});

test("SOUND ON/OFF/ON must be evidenced for both output routes", () => {
  const d = validEvidence(); d.observations.speaker.soundOffSilent = false;
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
  d.observations.speaker.soundOffSilent = true;
  d.observations.headphone.soundOnRestored = null;
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
});

test("FPS/heat PASS requires actual separate observations", () => {
  const d = validEvidence(); d.observations.fpsHeat.heatAssessment = "";
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
});

test("UNTESTED and FAIL stay separate from full readiness", () => {
  const d = validEvidence(); d.observations.speaker.status = "UNTESTED";
  assert.equal(inspect(d).verdict, "HOLD_UNTESTED");
  d.observations.speaker.status = "FAIL";
  assert.equal(inspect(d).verdict, "REQUIRES_FIX");
});

test("PASS without human evidence is invalid even with good metrics", () => {
  const d = validEvidence(); d.observations.warningRecognition.observedBy = "automation";
  assert.equal(inspect(d).verdict, "INVALID_RECORD");
});

test("build mismatch never permits readiness", () => {
  const d = validEvidence(); d.build.testedBuildMatchesVerifiedBuild = false;
  assert.equal(inspect(d).verdict, "HOLD_BUILD_VERIFICATION");
});
