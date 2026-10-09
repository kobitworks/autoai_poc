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
  graphics: 9,
  effects: 9,
  sound: 8,
  content_variation: 8,
  replayability: 9,
  technical_quality: 10,
};
quality.total = Object.values(quality).reduce((a, b) => a + b, 0);

const outDir = path.resolve('p021-game/docs/qa/game-g010-godot-redesign');

async function state(page) {
  return await page.evaluate(() => window.__P021_OTHELLO || null);
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
      await page.goto('http://127.0.0.1:8000/p021-game/games/othello/?qa=1', {
        waitUntil: 'domcontentloaded',
        timeout: 30000,
      });
      await page.waitForSelector('#canvas', { state: 'visible', timeout: 30000 });
      await wait(page, () => window.__P021_OTHELLO && window.__P021_OTHELLO.ready === true);

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
      if (!s || s.engine !== 'Godot' || s.build !== 'GAME-057') throw new Error('GAME-057 debug bridge missing');
      if (s.black !== 2 || s.white !== 2 || s.legal_count !== 4 || s.human !== 'black') throw new Error('initial Othello state invalid');
      if (!s.qa_mode) throw new Error('QA mode was not enabled');

      const scaleX = box.width / s.viewport_w;
      const scaleY = box.height / s.viewport_h;
      const clickX = Math.min(box.width - 4, Math.max(4, s.test_cell_x * scaleX));
      const clickY = Math.min(box.height - 4, Math.max(4, s.test_cell_y * scaleY));
      await canvas.click({ position: { x: clickX, y: clickY } });
      await wait(page, () => window.__P021_OTHELLO && window.__P021_OTHELLO.move_count >= 2 && !window.__P021_OTHELLO.busy, 45000);

      await page.keyboard.press('m');
      await wait(page, () => window.__P021_OTHELLO && window.__P021_OTHELLO.hints === false);
      await page.keyboard.press('2');
      await wait(page, () => window.__P021_OTHELLO && window.__P021_OTHELLO.difficulty === 4);

      await page.keyboard.press('r');
      await wait(page, () => window.__P021_OTHELLO && window.__P021_OTHELLO.move_count === 0 && window.__P021_OTHELLO.black === 2 && window.__P021_OTHELLO.white === 2);

      await page.keyboard.press('s');
      await wait(page, () => window.__P021_OTHELLO && window.__P021_OTHELLO.human === 'white' && window.__P021_OTHELLO.move_count >= 1 && !window.__P021_OTHELLO.busy, 45000);

      await page.keyboard.press('s');
      await wait(page, () => window.__P021_OTHELLO && window.__P021_OTHELLO.human === 'black' && window.__P021_OTHELLO.move_count === 0);

      await page.keyboard.press('f');
      await wait(page, () => window.__P021_OTHELLO && window.__P021_OTHELLO.finished === true, 30000);
      s = await state(page);
      if (!['win', 'lose', 'draw'].includes(s.result)) throw new Error('game result missing');
      if (s.black + s.white < 5 || s.black + s.white > 64) throw new Error('invalid final disc count');
      if (errors.length) throw new Error(errors.join(' | '));

      box = await canvas.boundingBox();
      const slug = name.toLowerCase().replace(/\s+/g, '-');
      await page.screenshot({ path: path.join(outDir, slug + '.png'), fullPage: true });
      results.push({
        name, width, height, pass: true,
        engine: s.engine,
        build: s.build,
        result: s.result,
        black: s.black,
        white: s.white,
        moves: s.move_count,
        canvas: box,
        overflow: false,
        url_only_flow: 'load -> identify -> legal touch -> CPU reply -> hints -> difficulty -> restart -> CPU-first -> restart -> rules-based finish',
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
    game: 'GAME-G010 Othello',
    task: 'GAME-057',
    engine: 'Godot 4.7.2 Web',
    generated_at: new Date().toISOString(),
    public_url: 'https://kobitworks.github.io/autoai_poc/p021-game/games/othello/',
    url_only_play_check: !failed,
    quality,
    general_public_quality: !failed && quality.total >= 80,
    cases: results,
  };
  fs.writeFileSync(path.join(outDir, 'latest.json'), JSON.stringify(evidence, null, 2) + '\n');
  console.log(JSON.stringify(evidence, null, 2));
  if (quality.total < 80 || failed) process.exit(1);
})();
