#!/usr/bin/env node
"use strict";
// Synthetic browser QA for GAME-076's offline recorder. No physical device,
// game completion, human observations, or acceptance score is certified here.
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { chromium } = require("playwright");
const { inspect } = require("./orbit-switch-courier-human-evidence.js");

const recorderURL = pathToFileURL(path.join(__dirname, "orbit-switch-courier-human-evidence-recorder.html")).href;
const gateKeys = ["first30s", "misTaps", "nightAce", "warningRecognition",
  "resultRetryBest", "speaker", "headphone", "fpsHeat", "physicalRotation"];

async function exportJSON(page) {
  const downloading = page.waitForEvent("download");
  await page.locator("#download").click();
  const downloaded = await downloading;
  assert.equal(downloaded.suggestedFilename(), "GAME-076-human-evidence.json");
  return JSON.parse(await fs.readFile(await downloaded.path(), "utf8"));
}

async function importJSON(page, obj) {
  await page.locator("#upload").setInputFiles({
    name: "synthetic-browser-test.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(obj), "utf8")
  });
}

async function runViewport(browser, width, height, mobile) {
  const context = await browser.newContext({
    viewport: { width, height },
    acceptDownloads: true,
    isMobile: mobile,
    hasTouch: mobile
  });
  const page = await context.newPage();
  const errors = [];
  const egress = [];
  page.on("pageerror", e => errors.push(String(e)));
  page.on("request", r => {
    if (/^https?:\/\//.test(r.url())) egress.push(r.url());
  });
  try {
    // Force an offline browser context. All UI logic must work from local HTML.
    await context.setOffline(true);
    await page.goto(recorderURL, { waitUntil: "load" });
    assert.equal(await page.locator('select[data-field="status"]').count(), 9);
    assert.deepEqual(
      await page.locator('select[data-field="status"]').evaluateAll(xs => xs.map(x => x.value)),
      Array(9).fill("UNTESTED")
    );
    assert.match(await page.locator("#progress").innerText(), /観測済み 0\/9/);
    assert.equal(await page.locator('select[data-scope="build"][data-field="liveByteGate"]').inputValue(),
      "UNVERIFIED");

    const before = await exportJSON(page);
    assert.deepEqual(Object.keys(before.observations), gateKeys);
    assert.equal(before.schemaVersion, "1.1");
    assert.equal(before.build.testedBuildMatchesVerifiedBuild, null);
    assert.equal(before.observations.first30s.firstActionSeconds, null);
    assert.deepEqual(before.observations.physicalRotation.orientations, []);
    assert.equal(inspect(before).verdict, "HOLD_DEVICE_DETAILS");
    assert.equal(inspect(before).eligibleForScoring, false);

    // Exercise typed field conversion and explicit FAIL without inventing PASS.
    await page.locator('select[data-scope="first30s"][data-field="status"]').selectOption("FAIL");
    await page.locator('input[data-scope="first30s"][data-field="firstActionSeconds"]').fill("12.5");
    await page.locator('select[data-scope="first30s"][data-field="firstCorrectActionObserved"]').selectOption("false");
    await page.locator('input[data-scope="nightAce"][data-field="nightDeliveries"]').fill("3");
    await page.locator('select[data-scope="nightAce"][data-field="naturalInput"]').selectOption("false");
    await page.locator('input[data-scope="physicalRotation"][data-field="orientations"][value="portrait"]').check();
    assert.match(await page.locator("#progress").innerText(), /観測済み 1\/9/);
    const filled = await exportJSON(page);
    assert.equal(filled.observations.first30s.status, "FAIL");
    assert.equal(filled.observations.first30s.firstActionSeconds, 12.5);
    assert.equal(filled.observations.first30s.firstCorrectActionObserved, false);
    assert.equal(filled.observations.nightAce.nightDeliveries, 3);
    assert.equal(filled.observations.nightAce.naturalInput, false);
    assert.deepEqual(filled.observations.physicalRotation.orientations, ["portrait"]);
    assert.equal(inspect(filled).eligibleForScoring, false);

    // Test local JSON import and exact round-trip, without upload or HTTP API.
    await page.reload();
    await importJSON(page, filled);
    await page.waitForFunction(() => document.querySelector("#message").textContent.includes("JSONを読み込みました"));
    assert.deepEqual(await exportJSON(page), filled);

    // Reject a wrong-version import; preserve existing fields.
    await importJSON(page, Object.assign({}, filled, { schemaVersion: "1.0" }));
    await page.waitForFunction(() => document.querySelector("#message").textContent.includes("読み込み失敗"));
    assert.deepEqual(await exportJSON(page), filled);

    const overflow = await page.evaluate(() =>
      document.documentElement.scrollWidth - document.documentElement.clientWidth);
    assert.ok(overflow <= 1, "Unexpected horizontal overflow: " + overflow + "px");
    for (const name of ["download", "uploadButton"]) {
      const rect = await page.locator("#" + name).boundingBox();
      assert.ok(rect && rect.height >= 40, "Save/load button has insufficient height: " + name);
    }
    assert.deepEqual(errors, []);
    assert.deepEqual(egress, []);
    console.log("PASS synthetic offline recorder browser QA " + width + "x" + height +
      "; 9/9 default UNTESTED; JSON download/upload, typed fields, version rejection, no network.");
  } finally {
    await context.close();
  }
}

(async () => {
  const browser = await chromium.launch({ headless: true, args: ["--no-sandbox"] });
  try {
    await runViewport(browser, 390, 844, true);
    await runViewport(browser, 844, 390, false);
    console.log("RECORDER_BROWSER_SMOKE_PASS (synthetic only; Human Gate remains UNTESTED)");
  } finally {
    await browser.close();
  }
})().catch(err => {
  console.error("RECORDER_BROWSER_SMOKE_FAIL", err);
  process.exitCode = 1;
});
