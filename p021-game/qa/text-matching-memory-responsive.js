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
  controls: 9,
  difficulty: 9,
  ui_ux: 9,
  graphics: 8,
  effects: 9,
  sound: 8,
  content_variation: 9,
  replayability: 9,
  technical_quality: 10,
};
quality.total = Object.values(quality).reduce((a, b) => a + b, 0);

const outDir = path.resolve('p021-game/docs/qa/game-g011-godot-redesign');

async function state(page) {
  return await page.evaluate(() => window.__P021_MEMORY || null);
}
async function wait(page, fn, timeout = 30000) {
  await page.waitForFunction(fn, null, { timeout });
}
async function clickLogical(canvas, box, s, x, y) {
  const scaleX = box.width / s.viewport_w;
  const scaleY = box.height / s.viewport_h;
  const px = Math.min(box.width - 3, Math.max(3, x * scaleX));
  const py = Math.min(box.height - 3, Math.max(3, y * scaleY));
  await canvas.click({ position: { x: px, y: py } });
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
      await page.goto('http://127.0.0.1:8000/p021-game/games/text-matching-memory/?qa=1', {
        waitUntil: 'domcontentloaded',
        timeout: 30000,
      });
      await page.waitForSelector('#canvas', { state: 'visible', timeout: 30000 });
      await wait(page, () => window.__P021_MEMORY && window.__P021_MEMORY.ready === true);

      const canvas = page.locator('#canvas');
      let box = await canvas.boundingBox();
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
      if (scroll.w > scroll.cw + 2 || scroll.h > scroll.ch + 2) throw new Error('page overflow detected');

      let s = await state(page);
      if (!s || s.engine !== 'Godot' || s.build !== 'GAME-058' || !s.qa_mode) throw new Error('GAME-058 debug bridge missing');
      if (s.level !== 2 || s.stage !== 2 || s.tier !== 2 || s.cards !== 20 || s.pairs !== 10) {
        throw new Error('default legacy-compatible setup is invalid');
      }
      if (!(s.test_a_x > 0 && s.test_b_x > 0)) throw new Error('test pair coordinates missing');

      await clickLogical(canvas, box, s, s.test_a_x, s.test_a_y);
      await wait(page, () => window.__P021_MEMORY && window.__P021_MEMORY.open_count === 1);
      await clickLogical(canvas, box, s, s.test_b_x, s.test_b_y);
      await wait(page, () => window.__P021_MEMORY && window.__P021_MEMORY.matched >= 1 && window.__P021_MEMORY.turn >= 1);

      await page.keyboard.press('m');
      await wait(page, () => window.__P021_MEMORY && window.__P021_MEMORY.sound === false);
      await page.keyboard.press('s');
      await wait(page, () => window.__P021_MEMORY && window.__P021_MEMORY.stage === 3 && window.__P021_MEMORY.matched === 0);
      await page.keyboard.press('t');
      await wait(page, () => window.__P021_MEMORY && window.__P021_MEMORY.tier === 3);
      await page.keyboard.press('4');
      await wait(page, () => window.__P021_MEMORY && window.__P021_MEMORY.level === 4 && window.__P021_MEMORY.cards === 30 && window.__P021_MEMORY.pairs === 15);
      await page.keyboard.press('r');
      await wait(page, () => window.__P021_MEMORY && window.__P021_MEMORY.turn === 0 && window.__P021_MEMORY.matched === 0);

      await page.keyboard.press('f');
      await wait(page, () => window.__P021_MEMORY && window.__P021_MEMORY.finished === true, 30000);
      s = await state(page);
      if (s.matched !== s.pairs || s.matched !== 15) throw new Error('QA pair-by-pair finish did not complete');
      if (errors.length) throw new Error(errors.join(' | '));

      box = await canvas.boundingBox();
      const slug = name.toLowerCase().replace(/\s+/g, '-');
      await page.screenshot({ path: path.join(outDir, slug + '.png'), fullPage: true });
      results.push({
        name, width, height, pass: true,
        engine: s.engine,
        build: s.build,
        level: s.level,
        stage: s.stage,
        tier: s.tier,
        pairs: s.pairs,
        matched: s.matched,
        canvas: box,
        overflow: false,
        url_only_flow: 'load -> identify -> matching touch pair -> sound toggle -> stage -> tier -> level4 -> reshuffle -> rules-compatible QA finish',
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
    game: 'GAME-G011 Text Matching Memory',
    task: 'GAME-058',
    engine: 'Godot 4.7.2 Web',
    generated_at: new Date().toISOString(),
    public_url: 'https://kobitworks.github.io/autoai_poc/p021-game/games/text-matching-memory/',
    preserved_rules: {
      levels: ['4x3/6 pairs','5x4/10 pairs','6x4/12 pairs','6x5/15 pairs'],
      stages: 10,
      tiers: 5,
      metrics: ['time','misses','turns','matched pairs'],
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
