import { chromium } from "playwright";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

const baseUrl = "http://127.0.0.1:4173/p021-game/games/wind-reader-glider/?qa=1";
const outDir = "p021-game/test-artifacts/game-g003-stage1";
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

  await page.goto(baseUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
  await page.locator("canvas").waitFor({ state: "visible", timeout: 120000 });
  await page.waitForTimeout(5000);

  const canvasBox = await page.locator("canvas").boundingBox();
  if (!canvasBox) throw new Error("Godot canvas has no bounding box");

  const titleShot = await page.screenshot({
    path: path.join(outDir, c.name + "-title.png"),
  });

  // QA mode is only enabled with ?qa=1. F9 advances deterministic
  // screen states while the actual game still runs the production scene.
  await page.keyboard.press("F9"); // title -> Stage 1
  await page.waitForTimeout(500);

  // Exercise real keyboard flight input and boost for the Stage 1 smoke.
  await page.keyboard.down("w");
  await page.keyboard.down(" ");
  await page.waitForTimeout(450);
  await page.keyboard.up(" ");
  await page.keyboard.up("w");

  // Exercise the real touch boost target once.
  await page.touchscreen.tap(
    Math.max(20, c.width - Math.max(68, c.width * 0.09)),
    Math.max(20, c.height - Math.max(76, c.height * 0.15)),
  );
  await page.waitForTimeout(250);

  const runningShot = await page.screenshot({
    path: path.join(outDir, c.name + "-running.png"),
  });

  await page.keyboard.press("F9"); // running -> clear result
  await page.waitForTimeout(300);
  const resultShot = await page.screenshot({
    path: path.join(outDir, c.name + "-result.png"),
  });

  await page.keyboard.press("F9"); // result -> retry
  await page.waitForTimeout(300);
  const retryShot = await page.screenshot({
    path: path.join(outDir, c.name + "-retry.png"),
  });

  const hashes = [
    digest(titleShot),
    digest(runningShot),
    digest(resultShot),
    digest(retryShot),
  ];
  const distinctScreens = new Set(hashes).size >= 3;
  const canvasFits =
    canvasBox.x >= -1 &&
    canvasBox.y >= -1 &&
    canvasBox.x + canvasBox.width <= c.width + 1 &&
    canvasBox.y + canvasBox.height <= c.height + 1;
  const pass =
    distinctScreens &&
    canvasFits &&
    consoleErrors.length === 0 &&
    pageErrors.length === 0;

  report.push({
    name: c.name,
    viewport: c.width + "x" + c.height,
    canvasFits,
    distinctScreens,
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
