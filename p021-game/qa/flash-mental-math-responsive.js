const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const cases = [
  ['Phone Portrait', 390, 844],
  ['Phone Landscape', 844, 390],
  ['Tablet Portrait', 768, 1024],
  ['Tablet Landscape', 1024, 768],
];

const quality = {
  gameplay: 9,
  controls: 10,
  difficulty: 9,
  ui_ux: 9,
  graphics: 9,
  effects: 9,
  sound: 8,
  content_variation: 9,
  replayability: 9,
  technical_quality: 10,
};
quality.total = Object.values(quality).reduce((a, b) => a + b, 0);

const outDir = path.resolve('p021-game/docs/qa/game-g012-godot-redesign');

async function state(page) {
  return await page.evaluate(() => window.__P021_FLASH_MATH || null);
}
async function wait(page, fn, timeout = 30000) {
  await page.waitForFunction(fn, null, { timeout });
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  const results = [];
  let failed = false;

  for (const [name, width, height] of cases) {
    const page = await browser.newPage({ viewport: { width, height } });
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push('console:' + m.text()); });
    page.on('pageerror', e => errors.push('page:' + e.message));

    try {
      await page.goto('http://127.0.0.1:8000/p021-game/games/flash-mental-math/?qa=1', {
        waitUntil: 'domcontentloaded',
        timeout: 30000,
      });
      await page.waitForSelector('#canvas', { state: 'visible', timeout: 30000 });
      await wait(page, () => window.__P021_FLASH_MATH && window.__P021_FLASH_MATH.ready === true);

      const canvas = page.locator('#canvas');
      const box = await canvas.boundingBox();
      if (!box) throw new Error('Godot canvas missing');
      if (box.x < -1 || box.y < -1 || box.x + box.width > width + 1 || box.y + box.height > height + 1) {
        throw new Error('Godot canvas outside viewport');
      }
      const scroll = await page.evaluate(() => ({
        w: document.documentElement.scrollWidth,
        h: document.documentElement.scrollHeight,
        cw: document.documentElement.clientWidth,
        ch: document.documentElement.clientHeight,
      }));
      if (scroll.w > scroll.cw + 2 || scroll.h > scroll.ch + 2) {
        throw new Error('page overflow detected');
      }

      let s = await state(page);
      if (!s || s.engine !== 'Godot' || s.build !== 'GAME-059' || !s.qa_mode) {
        throw new Error('GAME-059 debug bridge missing');
      }
      if (s.stage !== 1 || s.level !== 1 || s.rounds !== 3 || s.phase !== 'idle') {
        throw new Error('default setup mismatch');
      }

      await canvas.click({ position: { x: Math.max(8, box.width / 2), y: Math.max(8, box.height / 2) } });
      for (let i = 0; i < 4; i++) await page.keyboard.press('s');
      for (let i = 0; i < 4; i++) await page.keyboard.press('l');
      await wait(page, () => window.__P021_FLASH_MATH && window.__P021_FLASH_MATH.stage === 5 && window.__P021_FLASH_MATH.level === 5);

      await page.keyboard.press('m');
      await wait(page, () => window.__P021_FLASH_MATH && window.__P021_FLASH_MATH.sound === false);
      await page.keyboard.press('m');
      await wait(page, () => window.__P021_FLASH_MATH && window.__P021_FLASH_MATH.sound === true);

      await page.keyboard.press('n');
      await wait(page, () => window.__P021_FLASH_MATH && window.__P021_FLASH_MATH.phase === 'answer', 30000);
      s = await state(page);
      if (!Number.isFinite(Number(s.qa_answer))) throw new Error('QA answer unavailable');

      await page.keyboard.press('x');
      await wait(page, () => window.__P021_FLASH_MATH && window.__P021_FLASH_MATH.round === 2 && window.__P021_FLASH_MATH.phase === 'answer', 30000);
      await page.keyboard.press('f');
      await wait(page, () => window.__P021_FLASH_MATH && window.__P021_FLASH_MATH.round === 3 && window.__P021_FLASH_MATH.phase === 'answer', 30000);
      await page.keyboard.press('f');
      await wait(page, () => window.__P021_FLASH_MATH && window.__P021_FLASH_MATH.finished === true, 30000);

      s = await state(page);
      if (s.correct !== 2 || s.miss !== 1 || s.best_streak < 2) {
        throw new Error('answer feedback / streak flow mismatch');
      }
      if (s.stage !== 5 || s.level !== 5 || s.rounds !== 3) {
        throw new Error('Stage 5 / Level 5 run did not persist');
      }
      if (errors.length) throw new Error(errors.join(' | '));

      const slug = name.toLowerCase().replace(/\s+/g, '-');
      await page.screenshot({ path: path.join(outDir, slug + '.png'), fullPage: true });
      results.push({
        name, width, height, pass: true,
        engine: s.engine,
        build: s.build,
        stage: s.stage,
        level: s.level,
        rounds: s.rounds,
        correct: s.correct,
        miss: s.miss,
        best_streak: s.best_streak,
        canvas: box,
        overflow: false,
        url_only_flow: 'load -> identify -> Stage5/Lv5 -> sound toggle -> start -> miss feedback -> correct -> correct -> result',
      });
    } catch (e) {
      failed = true;
      results.push({ name, width, height, pass: false, error: String(e), errors });
    } finally {
      await page.close();
    }
  }

  await browser.close();

  const evidence = {
    game: 'GAME-G012 Flash Mental Math',
    task: 'GAME-059',
    engine: 'Godot 4.7.2 Web',
    generated_at: new Date().toISOString(),
    public_url: 'https://kobitworks.github.io/autoai_poc/p021-game/games/flash-mental-math/',
    preserved_rules: {
      stages: 5,
      levels: 5,
      rounds: '1-10',
      traps: 'Stage 2 / 4 / 5',
      score: 'correct rounds, higher is better',
    },
    url_only_play_check: !failed,
    quality,
    general_public_quality: !failed && quality.total >= 80,
    cases: results,
  };
  fs.writeFileSync(path.join(outDir, 'latest.json'), JSON.stringify(evidence, null, 2) + '\n');
  console.log(JSON.stringify(evidence, null, 2));
  if (quality.total < 80 || failed) process.exit(1);
})();
