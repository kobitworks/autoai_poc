#!/usr/bin/env node
"use strict";

// GAME-076: structure-only check for evidence gathered by an actual human tester.
// This tool NEVER runs physical-device tests and NEVER awards a quality score.
const fs = require("node:fs");

const GATES = [
  ["first30s", "Unassisted first 30 seconds / first correct action"],
  ["misTaps", "Finger mis-taps and touch targets"],
  ["nightAce", "NIGHT (3) and ACE (6) deliveries by natural input"],
  ["warningRecognition", "Recognition of the last-three-seconds warning"],
  ["resultRetryBest", "RESULT / RETRY / persisted BEST"],
  ["speaker", "Real device speaker and SOUND ON/OFF"],
  ["headphone", "Real headphones and SOUND ON/OFF"],
  ["fpsHeat", "At least three minutes of responsiveness and heat"],
  ["physicalRotation", "Actual portrait/landscape rotation"]
];
const STATES = new Set(["PASS", "FAIL", "UNTESTED"]);
const nonblank = (v, n = 1) => typeof v === "string" && v.trim().length >= n;
const number = v => Number.isFinite(v) && v >= 0;
function jst(v) {
  if (typeof v !== "string") return false;
  const m = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) JST$/.exec(v);
  if (!m) return false;
  const [year, month, day, hour, minute, second] = m.slice(1).map(Number);
  const t = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
  return t.getUTCFullYear() === year && t.getUTCMonth() + 1 === month
    && t.getUTCDate() === day && t.getUTCHours() === hour
    && t.getUTCMinutes() === minute && t.getUTCSeconds() === second;
}

// v1.1 requires measurable human observations; defaults never assert a PASS.
const MEASUREMENT_DEFAULTS = {
  first30s: { firstActionSeconds: null, firstCorrectActionObserved: null, goalUnderstoodUnprompted: null },
  misTaps: { count: null },
  nightAce: { nightDeliveries: null, aceDeliveries: null, naturalInput: null, stateInjected: null },
  warningRecognition: { recognitionSeconds: null },
  resultRetryBest: { bestPersisted: null },
  speaker: { soundOnAudible: null, soundOffSilent: null, soundOnRestored: null },
  headphone: { soundOnAudible: null, soundOffSilent: null, soundOnRestored: null },
  fpsHeat: { playMinutes: null, responsivenessAssessment: "", heatAssessment: "" },
  physicalRotation: { orientations: [] }
};

function blank() {
  return {
    schemaVersion: "1.1",
    build: {
      url: "https://kobitworks.github.io/autoai_poc/p021-game/games/orbit-switch-courier/",
      sourceCommit: "",
      actionsRunId: "",
      testedBuildMatchesVerifiedBuild: null,
      liveByteGate: "UNVERIFIED",
      verifiedAtJst: "",
      verificationEvidence: ""
    },
    device: { model: "", os: "", browser: "", testerAlias: "", testedAtJst: "" },
    observations: Object.fromEntries(GATES.map(([key]) => [key, {
      status: "UNTESTED", observedAtJst: "", evidence: "", notes: "", observedBy: "",
      ...MEASUREMENT_DEFAULTS[key]
    }]))
  };
}

function inspect(doc) {
  const errors = [], untested = [], failures = [];
  if (!doc || typeof doc !== "object" || Array.isArray(doc)) {
    return { verdict: "INVALID_RECORD", errors: ["Root JSON object is required"], eligibleForScoring: false };
  }
  if (doc.schemaVersion !== "1.1") errors.push("schemaVersion must be 1.1; generate a new --template");
  const b = doc.build || {}, d = doc.device || {}, o = doc.observations || {};
  for (const key of ["url", "sourceCommit", "actionsRunId", "liveByteGate", "verifiedAtJst", "verificationEvidence"]) {
    if (typeof b[key] !== "string") errors.push("build." + key + " must be a string");
  }
  if (!nonblank(b.url, 12) || !/^https:\/\//.test(b.url || "")) errors.push("build.url must be HTTPS");
  if (b.sourceCommit && !/^[0-9a-f]{40}$/.test(b.sourceCommit)) errors.push("build.sourceCommit must be a full SHA-1");
  if (!["PASS_LIVE_BYTES", "UNVERIFIED", "FAIL_MISMATCH"].includes(b.liveByteGate)) errors.push("build.liveByteGate is invalid");
  if (b.verifiedAtJst && !jst(b.verifiedAtJst)) errors.push("build.verifiedAtJst must be a real JST timestamp");
  if (b.testedBuildMatchesVerifiedBuild !== null && typeof b.testedBuildMatchesVerifiedBuild !== "boolean") {
    errors.push("build.testedBuildMatchesVerifiedBuild must be true, false, or null");
  }
  for (const key of ["model", "os", "browser", "testerAlias", "testedAtJst"]) {
    if (typeof d[key] !== "string") errors.push("device." + key + " must be a string");
  }
  if (d.testedAtJst && !jst(d.testedAtJst)) errors.push("device.testedAtJst must be a real JST timestamp");
  const deviceReady = ["model", "os", "browser", "testerAlias"].every(k => nonblank(d[k])) && jst(d.testedAtJst);
  const buildReady = b.liveByteGate === "PASS_LIVE_BYTES"
    && b.testedBuildMatchesVerifiedBuild === true
    && /^[0-9a-f]{40}$/.test(b.sourceCommit || "")
    && nonblank(b.actionsRunId) && jst(b.verifiedAtJst)
    && nonblank(b.verificationEvidence, 12);
  for (const [key] of GATES) {
    const g = o[key];
    if (!g || typeof g !== "object" || Array.isArray(g)) {
      errors.push("observations." + key + " must be an object");
      continue;
    }
    if (!STATES.has(g.status)) {
      errors.push("observations." + key + ".status must be PASS / FAIL / UNTESTED");
      continue;
    }
    if (g.status === "UNTESTED") { untested.push(key); continue; }
    if (!nonblank(g.evidence, 12) || !jst(g.observedAtJst) || g.observedBy !== "human") {
      errors.push("observations." + key + " needs specific evidence (12+ chars), JST timestamp, observedBy=human");
    }
    if (g.status === "FAIL") failures.push(key);
    if (g.status !== "PASS") continue;
    if (key === "first30s" && (!number(g.firstActionSeconds) || g.firstActionSeconds > 30
      || g.firstCorrectActionObserved !== true || g.goalUnderstoodUnprompted !== true))
      errors.push("first30s PASS requires <=30 seconds, correct first action, and unprompted goal understanding");
    if (key === "misTaps" && (!Number.isInteger(g.count) || g.count < 0))
      errors.push("misTaps PASS requires observed nonnegative integer count");
    if (key === "nightAce" && (!Number.isInteger(g.nightDeliveries) || g.nightDeliveries < 3
      || !Number.isInteger(g.aceDeliveries) || g.aceDeliveries < 6
      || g.naturalInput !== true || g.stateInjected !== false))
      errors.push("nightAce PASS requires NIGHT>=3, ACE>=6, naturalInput=true, stateInjected=false");
    if (key === "warningRecognition" && (!number(g.recognitionSeconds) || g.recognitionSeconds > 3))
      errors.push("warningRecognition PASS requires recognitionSeconds within 0..3");
    if (key === "resultRetryBest" && g.bestPersisted !== true)
      errors.push("resultRetryBest PASS requires bestPersisted=true");
    if ((key === "speaker" || key === "headphone")
      && (g.soundOnAudible !== true || g.soundOffSilent !== true || g.soundOnRestored !== true))
      errors.push(key + " PASS requires audible ON, silent OFF, and audible ON again on the actual output route");
    if (key === "fpsHeat" && (!number(g.playMinutes) || g.playMinutes < 3
      || !nonblank(g.responsivenessAssessment, 12) || !nonblank(g.heatAssessment, 12)))
      errors.push("fpsHeat PASS requires >=3 minutes and separate responsiveness/heat observations (12+ chars each)");
    if (key === "physicalRotation" && (!Array.isArray(g.orientations) || !["portrait", "landscape"].every(x => g.orientations.includes(x))))
      errors.push("physicalRotation PASS requires portrait and landscape evidence");
  }
  if (errors.length) return { verdict: "INVALID_RECORD", errors, eligibleForScoring: false };
  const verdict = !deviceReady ? "HOLD_DEVICE_DETAILS"
    : !buildReady ? "HOLD_BUILD_VERIFICATION"
    : untested.length ? "HOLD_UNTESTED"
    : failures.length ? "REQUIRES_FIX"
    : "READY_FOR_INDEPENDENT_SCORING";
  return {
    verdict,
    eligibleForScoring: verdict === "READY_FOR_INDEPENDENT_SCORING",
    testedGateCount: GATES.length - untested.length,
    totalGateCount: GATES.length,
    untested, failures,
    note: "Evidence fields are not authenticated; a human must review all claims. No physical test was run by this tool and no 80/100 score is awarded."
  };
}

function main(argv) {
  if (argv.length === 1 && argv[0] === "--template") {
    process.stdout.write(JSON.stringify(blank(), null, 2) + "\n");
    return 0;
  }
  if (argv.length !== 1 || argv[0].startsWith("-")) {
    process.stderr.write("Usage: node orbit-switch-courier-human-evidence.js --template | PATH_TO_EVIDENCE.json\n");
    return 2;
  }
  try {
    const document = JSON.parse(fs.readFileSync(argv[0], "utf8"));
    const result = inspect(document);
    process.stdout.write(JSON.stringify(result, null, 2) + "\n");
    return result.verdict === "READY_FOR_INDEPENDENT_SCORING" ? 0 : result.verdict === "INVALID_RECORD" ? 2 : 3;
  } catch (e) {
    process.stderr.write("Input could not be read or parsed: " + e.message + "\n");
    return 2;
  }
}

if (require.main === module) process.exitCode = main(process.argv.slice(2));
module.exports = { inspect, blank, GATES };
