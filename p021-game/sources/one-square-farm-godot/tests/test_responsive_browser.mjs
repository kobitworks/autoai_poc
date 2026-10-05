import { chromium } from "playwright";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const cases = [
  { name: "phone-portrait", width: 390, height: 844 },
  { name: "phone-landscape", width: 844, height: 390 },
  { name: "tablet-portrait", width: 768, height: 1024 },
  { name: "tablet-landscape", width: 1024, height: 768 },
];

const baseUrl = process.env.GAME_URL || "http://127.0.0.1:4173/games/one-square-farm-godot-v5/";
const outDir = "p021-game/docs/qa/game-g001-responsive";
fs.mkdirSync(outDir, { recursive: true });

const sha256 = (buf) => crypto.createHash("sha256").update(buf).digest("hex");
const browser = await chromium.launch({ headless: true });
const report = {
  checkedAt: new Date().toISOString(),
  url: baseUrl,
  task: "GAME-023",
  cases: [],
};

let failed = false;

for (const item of cases) {
  const page = await browser.newPage({ viewport: { width: item.width, height: item.height } });
  const consoleErrors = [];
  const pageErrors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });
  page.on("pageerror", (err) => pageErrors.push(String(err)));

  try {
    await page.goto(baseUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
    await page.waitForSelector("#canvas", { state: "visible", timeout: 120000 });
    await page.waitForFunction(() => !document.querySelector("#status"), null, { timeout: 180000 });
    await page.waitForTimeout(1200);

    const canvas = page.locator("#canvas");
    const box = await canvas.boundingBox();
    if (!box) throw new Error("canvas bounding box is unavailable");
    if (box.width < item.width * 0.95 || box.height < item.height * 0.95) {
      throw new Error(`canvas does not fill viewport: ${box.width}x${box.height}`);
    }

    await page.mouse.click(box.x + box.width / 2, box.y + Math.min(box.height / 2, 180));
    await page.keyboard.press("2");
    await page.waitForTimeout(250);

    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    for (let i = 0; i < 8; i += 1) {
      await page.mouse.wheel(0, 700);
      await page.waitForTimeout(40);
    }
    await page.waitForTimeout(250);

    const introPath = path.join(outDir, `${item.name}-intro-ready.png`);
    const introBuf = await page.screenshot({ path: introPath, fullPage: false });
    if (introBuf.length < 5000) throw new Error("intro screenshot is unexpectedly small");

    const clickX = box.x + box.width / 2;
    const clickY = box.y + Math.max(20, box.height - (item.height <= 500 ? 68 : 78));
    await page.mouse.click(clickX, clickY);
    await page.waitForTimeout(1400);

    const gamePath = path.join(outDir, `${item.name}-game.png`);
    const gameBuf = await page.screenshot({ path: gamePath, fullPage: false });
    if (gameBuf.length < 5000) throw new Error("game screenshot is unexpectedly small");

    const introHash = sha256(introBuf);
    const gameHash = sha256(gameBuf);
    const changedAfterStartClick = introHash !== gameHash;
    if (!changedAfterStartClick) throw new Error("start-button click did not change the rendered screen");

    report.cases.push({
      ...item,
      canvas: { width: box.width, height: box.height },
      selectedChallengeByKeyboard: "sprint",
      startClick: { x: Math.round(clickX), y: Math.round(clickY) },
      introScreenshot: introPath,
      gameScreenshot: gamePath,
      introSha256: introHash,
      gameSha256: gameHash,
      changedAfterStartClick,
      consoleErrors,
      pageErrors,
      result: pageErrors.length === 0 ? "PASS" : "WARN",
    });
    if (pageErrors.length > 0) failed = true;
  } catch (err) {
    failed = true;
    report.cases.push({
      ...item,
      result: "FAIL",
      error: String(err),
      consoleErrors,
      pageErrors,
    });
  } finally {
    await page.close();
  }
}

await browser.close();
report.result = failed ? "FAIL" : "PASS";
fs.writeFileSync(path.join(outDir, "report.json"), JSON.stringify(report, null, 2) + "\n");
console.log(JSON.stringify(report, null, 2));
if (failed) process.exit(1);
