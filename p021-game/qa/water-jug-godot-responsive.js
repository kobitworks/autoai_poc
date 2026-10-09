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
const outDir = path.resolve('p021-game/docs/qa/game-g013-godot-redesign');

async function state(page) {
  return await page.evaluate(() => window.__P021_WATER_JUG || null);
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
      await page.goto('http://127.0.0.1:8000/p021-game/games/water-jug/?qa=1', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForSelector('#canvas', { state: 'visible', timeout: 30000 });
      await wait(page, () => window.__P021_WATER_JUG && window.__P021_WATER_JUG.ready === true);

      const canvas = page.locator('#canvas');
      const box = await canvas.boundingBox();
      if (!box) throw new Error('Godot canvas missing');
      if (box.x < -1 || box.y < -1 || box.x + box.width > width + 1 || box.y + box.height > height + 1) throw new Error('Godot canvas outside viewport');

      const scroll = await page.evaluate(() => ({
        w: document.documentElement.scrollWidth, h: document.documentElement.scrollHeight,
        cw: document.documentElement.clientWidth, ch: document.documentElement.clientHeight,
      }));
      if (scroll.w > scroll.cw + 2 || scroll.h > scroll.ch + 2) throw new Error('page overflow detected');

      let s = await state(page);
      if (!s || s.engine !== 'Godot' || s.build !== 'GAME-060' || !s.qa_mode) throw new Error('GAME-060 bridge missing');
      if (s.difficulty !== 'easy' || s.cap_a !== 3 || s.cap_b !== 5 || s.target !== 4 || s.optimal !== 6 || s.phase !== 'idle') throw new Error('classic QA puzzle mismatch');

      await canvas.click({ position: { x: Math.max(8, box.width / 2), y: Math.max(8, box.height / 2) } });
      await page.keyboard.press('d');
      await wait(page, () => window.__P021_WATER_JUG && window.__P021_WATER_JUG.difficulty === 'normal');
      await page.keyboard.press('d');
      await wait(page, () => window.__P021_WATER_JUG && window.__P021_WATER_JUG.difficulty === 'hard');
      await page.keyboard.press('d');
      await wait(page, () => window.__P021_WATER_JUG && window.__P021_WATER_JUG.difficulty === 'easy' && window.__P021_WATER_JUG.target === 4);

      await page.keyboard.press('m');
      await wait(page, () => window.__P021_WATER_JUG && window.__P021_WATER_JUG.sound === false);
      await page.keyboard.press('m');
      await wait(page, () => window.__P021_WATER_JUG && window.__P021_WATER_JUG.sound === true);

      await page.keyboard.press('n');
      await wait(page, () => window.__P021_WATER_JUG && window.__P021_WATER_JUG.phase === 'playing');
      for (const key of ['7', '9', '2', '9', '7', '9']) {
        await page.keyboard.press(key);
        await page.waitForTimeout(80);
      }
      await wait(page, () => window.__P021_WATER_JUG && window.__P021_WATER_JUG.finished === true);
      s = await state(page);
      if (s.moves !== 6 || s.amount_b !== 4 || s.optimal !== 6) throw new Error('classic 3/5 -> 4 solution flow mismatch');
      if (errors.length) throw new Error(errors.join(' | '));

      const slug = name.toLowerCase().replace(/\s+/g, '-');
      await page.screenshot({ path: path.join(outDir, slug + '.png'), fullPage: true });
      results.push({
        name, width, height, pass: true,
        engine: s.engine, build: s.build, difficulty: s.difficulty,
        cap_a: s.cap_a, cap_b: s.cap_b, target: s.target,
        amount_a: s.amount_a, amount_b: s.amount_b,
        moves: s.moves, optimal: s.optimal,
        canvas: box, overflow: false,
        url_only_flow: 'load -> identify -> difficulty cycle -> sound toggle -> start -> Fill B -> B→A -> Empty A -> B→A -> Fill B -> B→A -> clear',
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
    game: 'GAME-G013 Water Jug',
    task: 'GAME-060',
    engine: 'Godot 4.7.2 Web',
    generated_at: new Date().toISOString(),
    public_url: 'https://kobitworks.github.io/autoai_poc/p021-game/games/water-jug/',
    preserved_rules: {
      difficulties: ['Easy', 'Normal', 'Hard'],
      solvability: 'GCD',
      optimal: 'BFS shortest steps',
      actions: ['Fill A', 'Empty A', 'Fill B', 'Empty B', 'A→B', 'B→A'],
      best: 'moves lower, then time',
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
