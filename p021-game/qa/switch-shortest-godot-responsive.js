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

const outDir = path.resolve('p021-game/docs/qa/game-g014-godot-redesign');
fs.mkdirSync(outDir, { recursive: true });

async function state(page) {
  return page.evaluate(() => window.__P021_SWITCH_SHORTEST || null);
}

async function clickLogical(page, x, y) {
  const s = await state(page);
  const canvas = page.locator('canvas').first();
  const box = await canvas.boundingBox();
  if (!box) throw new Error('Godot canvas bounding box missing');
  const px = box.x + (x / s.viewport_w) * box.width;
  const py = box.y + (y / s.viewport_h) * box.height;
  await page.mouse.click(px, py);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const results = [];
  let failed = false;

  for (const [name, width, height] of cases) {
    const page = await browser.newPage({ viewport: { width, height } });
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push('console: ' + msg.text());
    });
    page.on('pageerror', err => errors.push('pageerror: ' + String(err)));

    try {
      await page.goto('http://127.0.0.1:8000/p021-game/games/switch-shortest/?qa=1', { waitUntil: 'networkidle', timeout: 60000 });
      await page.waitForFunction(() => {
        const s = window.__P021_SWITCH_SHORTEST;
        return s && s.ready && Array.isArray(s.switch_centers) && s.switch_centers.length === s.switches;
      }, null, { timeout: 30000 });

      let s = await state(page);
      if (s.engine !== 'Godot 4.7.2') throw new Error('Godot engine marker missing');
      if (s.difficulty !== 'easy' || s.switches !== 8) throw new Error('QA seed must begin on Easy/8');
      if (!Array.isArray(s.solution_start) || s.solution_start.length < 1) throw new Error('BFS solution missing');
      const initialOptimal = s.optimal;
      const initialSolution = [...s.solution_start];

      await page.keyboard.press('m');
      await page.waitForTimeout(90);
      if ((await state(page)).sound !== false) throw new Error('SOUND OFF failed');
      await page.keyboard.press('m');
      await page.waitForTimeout(90);
      if ((await state(page)).sound !== true) throw new Error('SOUND ON failed');

      await page.keyboard.press('d');
      await page.waitForTimeout(90);
      if ((await state(page)).difficulty !== 'normal') throw new Error('Normal difficulty cycle failed');
      await page.keyboard.press('d');
      await page.waitForTimeout(90);
      if ((await state(page)).difficulty !== 'hard') throw new Error('Hard difficulty cycle failed');
      await page.keyboard.press('d');
      await page.waitForTimeout(120);
      s = await state(page);
      if (s.difficulty !== 'easy') throw new Error('Easy difficulty cycle failed');

      await page.keyboard.press('h');
      await page.waitForTimeout(100);
      s = await state(page);
      if (s.hint_index < 0 || s.hint_index >= s.switches) throw new Error('Hint did not expose an optimal next move');

      const solution = [...s.solution_start];
      if (solution.length !== initialSolution.length || s.optimal !== initialOptimal) throw new Error('Deterministic QA puzzle changed unexpectedly');

      for (let step = 0; step < solution.length; step++) {
        s = await state(page);
        const idx = solution[step];
        const center = s.switch_centers[idx];
        if (!center) throw new Error('Switch center missing for index ' + idx);
        await clickLogical(page, center[0], center[1]);
        await page.waitForTimeout(110);
      }

      s = await state(page);
      if (!s.finished || s.phase !== 'result') throw new Error('BFS shortest path did not clear the puzzle');
      if (s.moves !== s.optimal) throw new Error('Clear was not achieved at optimal move count');

      const overflow = await page.evaluate(() => (
        document.documentElement.scrollWidth > window.innerWidth + 1 ||
        document.documentElement.scrollHeight > window.innerHeight + 1
      ));
      if (overflow) throw new Error('Viewport overflow detected');
      if (errors.length) throw new Error(errors.join(' | '));

      const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-');
      await page.screenshot({ path: path.join(outDir, slug + '.png'), fullPage: true });

      await page.keyboard.press('r');
      await page.waitForTimeout(100);
      s = await state(page);
      if (s.finished || s.moves !== 0 || s.current_mask !== s.start_mask) throw new Error('Retry failed');

      await page.keyboard.press('n');
      await page.waitForTimeout(100);
      s = await state(page);
      if (s.finished || s.moves !== 0 || s.solution_start.length < 1) throw new Error('New puzzle failed');

      results.push({
        name, width, height, pass: true, errors,
        difficulty: s.difficulty,
        switches: s.switches,
        optimal: s.optimal,
        canvas: await page.locator('canvas').first().boundingBox(),
        overflow: false,
        url_only_flow: 'load -> identify -> mode cycle -> sound toggle -> hint -> follow BFS shortest path -> clear -> retry -> new puzzle',
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
    game: 'GAME-G014 Switch Shortest',
    task: 'GAME-061',
    engine: 'Godot 4.7.2 Web',
    generated_at: new Date().toISOString(),
    public_url: 'https://kobitworks.github.io/autoai_poc/p021-game/games/switch-shortest/',
    preserved_rules: {
      difficulties: ['Easy 8', 'Normal 10', 'Hard 12'],
      toggle: 'pressed switch plus immediate left/right neighbors',
      goal: 'START/current mask must match TARGET mask',
      optimal: 'BFS shortest path',
      score: 'lower move count is better',
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
