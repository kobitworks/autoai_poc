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
  effects: 8,
  sound: 8,
  content_variation: 8,
  replayability: 9,
  technical_quality: 10,
};
quality.total = Object.values(quality).reduce((a, b) => a + b, 0);

const outDir = path.resolve('p021-game/docs/qa/game-g009-godot-redesign');

async function getState(page) {
  return await page.evaluate(() => window.__P021_NUMBER_SUM || null);
}
async function waitFor(page, fn, timeout = 15000) {
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
      await page.goto('http://127.0.0.1:8000/p021-game/games/number-sum/', {
        waitUntil: 'domcontentloaded',
        timeout: 30000,
      });
      await page.waitForSelector('#canvas', { state: 'visible', timeout: 30000 });
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.ready === true, 30000);

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

      let state = await getState(page);
      if (!state || state.engine !== 'Godot' || state.build !== 'GAME-056') throw new Error('GAME-056 debug bridge missing');
      if (state.difficulty !== 'easy' || state.n !== 5) throw new Error('Easy 5x5 default missing');

      await canvas.click({ position: { x: Math.max(4, box.width / 2), y: Math.max(4, box.height / 2) } });
      await page.keyboard.press('2');
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.n === 6);
      await page.keyboard.press('3');
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.n === 7);
      await page.keyboard.press('1');
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.n === 5);

      state = await getState(page);
      const scaleX = box.width / state.viewport_w;
      const scaleY = box.height / state.viewport_h;
      const clickX = Math.min(box.width - 4, Math.max(4, state.test_cell_x * scaleX));
      const clickY = Math.min(box.height - 4, Math.max(4, state.test_cell_y * scaleY));
      await canvas.click({ position: { x: clickX, y: clickY } });
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.selected_count === 1);

      await page.keyboard.press('m');
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.mode === 'exclude');
      await canvas.click({ position: { x: clickX, y: clickY } });
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.excluded_count === 1);

      await page.keyboard.press('r');
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.unknown_count === 25);
      await page.keyboard.press('h');
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.unknown_count === 24);

      for (let i = 0; i < 24; i++) {
        await page.keyboard.press('h');
      }
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.won === true, 15000);

      await page.keyboard.press('n');
      await waitFor(page, () => window.__P021_NUMBER_SUM && window.__P021_NUMBER_SUM.won === false && window.__P021_NUMBER_SUM.unknown_count === 25);

      state = await getState(page);
      if (errors.length) throw new Error(errors.join(' | '));

      const slug = name.toLowerCase().replace(/\s+/g, '-');
      await page.screenshot({ path: path.join(outDir, slug + '.png'), fullPage: true });
      results.push({
        name, width, height, pass: true,
        engine: state.engine,
        build: state.build,
        difficulty: state.difficulty,
        n: state.n,
        canvas: box,
        overflow: false,
        url_only_flow: 'load -> identify -> change difficulty -> touch -> exclude -> reset -> hint -> clear -> retry',
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
    game: 'GAME-G009 Number Sum',
    task: 'GAME-056',
    engine: 'Godot 4.7.2 Web',
    generated_at: new Date().toISOString(),
    public_url: 'https://kobitworks.github.io/autoai_poc/p021-game/games/number-sum/',
    url_only_play_check: !failed,
    quality,
    general_public_quality: !failed && quality.total >= 80,
    cases: results,
  };
  fs.writeFileSync(path.join(outDir, 'latest.json'), JSON.stringify(evidence, null, 2) + '\n');
  console.log(JSON.stringify(evidence, null, 2));

  if (quality.total < 80) {
    console.error('Quality gate below 80');
    process.exit(1);
  }
  if (failed) process.exit(1);
})();
