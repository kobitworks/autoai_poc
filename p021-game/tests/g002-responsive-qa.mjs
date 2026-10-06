import { chromium } from "playwright";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

const baseUrl = "http://127.0.0.1:4173/p021-game/games/past-self-coop-v2/?qa=1";
const outDir = "p021-game/test-artifacts/game-g002-responsive";
const cases = [
  { name: "phone-portrait", width: 390, height: 844 },
  { name: "phone-landscape", width: 844, height: 390 },
  { name: "tablet-portrait", width: 768, height: 1024 },
  { name: "tablet-landscape", width: 1024, height: 768 },
];

await fs.mkdir(outDir, { recursive: true });
const browser = await chromium.launch({ headless: true });
const report = [];

function digest(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

async function layoutPoint(page, logicalX, logicalY, portrait) {
  const box = await page.locator("canvas").boundingBox();
  if (!box) throw new Error("Godot canvas has no bounding box");
  const logicalW = portrait ? 640 : 960;
  const logicalH = portrait ? 960 : 640;
  const scale = Math.min(box.width / logicalW, box.height / logicalH);
  const offsetX = box.x + (box.width - logicalW * scale) / 2;
  const offsetY = box.y + (box.height - logicalH * scale) / 2;
  return { x: offsetX + logicalX * scale, y: offsetY + logicalY * scale };
}

for (const c of cases) {
  const context = await browser.newContext({
    viewport: { width: c.width, height: c.height },
    hasTouch: true,
    isMobile: true,
  });
  const page = await context.newPage();
  const consoleErrors = [];
  const pageErrors = [];
  page.on("console", msg => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });
  page.on("pageerror", err => pageErrors.push(String(err)));

  await page.goto(baseUrl, { waitUntil: "networkidle", timeout: 120000 });
  await page.locator("canvas").waitFor({ state: "visible", timeout: 120000 });
  await page.waitForTimeout(2500);

  // QA mode is only enabled with ?qa=1. It deterministically advances state
  // while still rendering the real stage/clear/complete UI at each viewport.
  await page.keyboard.press("F9"); // intro -> stage 1
  const stageHashes = [];
  for (let stage = 1; stage <= 3; stage += 1) {
    await page.keyboard.press("F9"); // stage -> CLEAR
    await page.waitForTimeout(180);
    const snap = await page.screenshot({
      path: path.join(outDir, `${c.name}-stage-${stage}-clear.png`),
    });
    stageHashes.push(digest(snap));
    await page.keyboard.press("F9"); // next stage or COMPLETE
    await page.waitForTimeout(180);
  }

  const completeShot = await page.screenshot({
    path: path.join(outDir, `${c.name}-complete.png`),
  });
  const completeHash = digest(completeShot);

  const portrait = c.height > c.width;
  const restartCenter = portrait ? { x: 320, y: 686 } : { x: 480, y: 459 };
  const restart = await layoutPoint(page, restartCenter.x, restartCenter.y, portrait);
  await page.touchscreen.tap(restart.x, restart.y);
  await page.waitForTimeout(250);
  const restartShot = await page.screenshot({
    path: path.join(outDir, `${c.name}-restart.png`),
  });
  const restartHash = digest(restartShot);

  // Cycle the real SFX control once to cover the touch target and persistence path.
  const audioCenter = portrait ? { x: 476, y: 911 } : { x: 625, y: 582 };
  const audio = await layoutPoint(page, audioCenter.x, audioCenter.y, portrait);
  await page.touchscreen.tap(audio.x, audio.y);
  await page.waitForTimeout(100);

  const uniqueStages = new Set(stageHashes).size === 3;
  const pass = uniqueStages &&
    completeHash !== restartHash &&
    consoleErrors.length === 0 &&
    pageErrors.length === 0;

  report.push({
    name: c.name,
    viewport: `${c.width}x${c.height}`,
    stageScreensUnique: uniqueStages,
    completeToRestartChanged: completeHash !== restartHash,
    consoleErrors,
    pageErrors,
    pass,
  });
  await context.close();
}

await browser.close();
await fs.writeFile(
  path.join(outDir, "report.json"),
  JSON.stringify(report, null, 2) + "\n",
  "utf8",
);

console.log(JSON.stringify(report, null, 2));
if (report.some(item => !item.pass)) process.exit(1);
