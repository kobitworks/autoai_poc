import { chromium } from "playwright";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

const baseUrl = "http://127.0.0.1:4173/p021-game/games/shadow-step-stealth/?qa=1";
const outDir = "p021-game/test-artifacts/game-g008-three-stage";
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
  const canvas = page.locator("canvas");
  await canvas.waitFor({ state: "visible", timeout: 120000 });
  await page.waitForTimeout(5000);
  const box = await canvas.boundingBox();
  if (!box) throw new Error("GAME-G008 canvas has no bounding box");

  const images = [];
  images.push(await shot(page, c.name + "-title"));

  await page.keyboard.press("F4");
  await page.waitForTimeout(250);
  images.push(await shot(page, c.name + "-stage-select"));

  await page.keyboard.press("F9");
  await page.waitForTimeout(350);
  images.push(await shot(page, c.name + "-stage1"));

  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(850);
  images.push(await shot(page, c.name + "-stage1-move"));

  await page.keyboard.press("F8");
  await page.waitForTimeout(160);
  images.push(await shot(page, c.name + "-stage1-alert"));

  await page.keyboard.press("F9");
  await page.waitForTimeout(220);
  images.push(await shot(page, c.name + "-stage1-result"));

  await page.keyboard.press("F6");
  await page.waitForTimeout(280);
  images.push(await shot(page, c.name + "-stage2"));

  await page.keyboard.press("F9");
  await page.waitForTimeout(220);
  images.push(await shot(page, c.name + "-stage2-result"));

  await page.keyboard.press("F6");
  await page.waitForTimeout(280);
  images.push(await shot(page, c.name + "-stage3"));

  await page.keyboard.press("F7");
  await page.waitForTimeout(180);
  images.push(await shot(page, c.name + "-stage3-phase2"));

  await page.keyboard.press("F9");
  await page.waitForTimeout(220);
  images.push(await shot(page, c.name + "-stage3-result"));

  await page.keyboard.press("r");
  await page.waitForTimeout(220);
  images.push(await shot(page, c.name + "-stage3-retry"));

  const hashes = images.map(digest);
  const screenCount = new Set(hashes).size;
  const distinctScreens = screenCount >= 9;
  const canvasFits =
    box.x >= -1 &&
    box.y >= -1 &&
    box.x + box.width <= c.width + 1 &&
    box.y + box.height <= c.height + 1;
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
    screenCount,
    testedFlow: [
      "title",
      "stage-select",
      "stage1",
      "stage1-move",
      "stage1-alert",
      "stage1-result",
      "stage2",
      "stage2-result",
      "stage3",
      "stage3-phase2",
      "stage3-result",
      "stage3-retry",
    ],
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
