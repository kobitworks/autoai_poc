import { chromium } from "playwright";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

const baseUrl = "http://127.0.0.1:4173/p021-game/games/wind-reader-glider/?qa=1";
const outDir = "p021-game/test-artifacts/game-g007-stage-flow";
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

async function shot(page, name) {
  return page.screenshot({ path: path.join(outDir, name + ".png") });
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

  const images = [];
  images.push(await shot(page, c.name + "-title"));

  await page.keyboard.press("F9"); // title -> stage select
  await page.waitForTimeout(250);
  images.push(await shot(page, c.name + "-stage-select"));

  await page.keyboard.press("F9"); // stage select -> stage 1
  await page.waitForTimeout(300);
  await page.keyboard.down("w");
  await page.keyboard.down(" ");
  await page.waitForTimeout(300);
  await page.keyboard.up(" ");
  await page.keyboard.up("w");
  images.push(await shot(page, c.name + "-stage1"));

  await page.keyboard.press("F9"); // stage 1 -> result
  await page.waitForTimeout(250);
  images.push(await shot(page, c.name + "-result1"));

  // Touch Retry on the real result button, then clear Stage 1 again.
  if (c.height > c.width) {
    await page.touchscreen.tap(c.width * 0.50, c.height * 0.61);
  } else {
    await page.touchscreen.tap(c.width * 0.19, c.height * 0.73);
  }
  await page.waitForTimeout(250);
  images.push(await shot(page, c.name + "-retry1"));
  await page.keyboard.press("F9"); // retried Stage 1 -> result
  await page.waitForTimeout(180);
  await page.keyboard.press("F9"); // result -> Stage 2
  await page.waitForTimeout(250);
  images.push(await shot(page, c.name + "-stage2"));

  await page.keyboard.press("F9"); // Stage 2 -> result
  await page.waitForTimeout(180);
  await page.keyboard.press("F9"); // result -> Stage 3
  await page.waitForTimeout(250);
  images.push(await shot(page, c.name + "-stage3"));

  await page.keyboard.press("F9"); // Stage 3 -> result
  await page.waitForTimeout(250);
  images.push(await shot(page, c.name + "-result3"));

  // Touch Stage Select from final result.
  if (c.height > c.width) {
    await page.touchscreen.tap(c.width * 0.50, c.height * 0.79);
  } else {
    await page.touchscreen.tap(c.width * 0.81, c.height * 0.73);
  }
  await page.waitForTimeout(250);
  images.push(await shot(page, c.name + "-stage-select-final"));

  const hashes = images.map(digest);
  const distinctScreens = new Set(hashes).size >= 7;
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
    screenCount: new Set(hashes).size,
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
