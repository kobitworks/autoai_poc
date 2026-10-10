const { chromium } = require('playwright');

const cases = [
  ['Phone Portrait', 390, 844],
  ['Phone Landscape', 844, 390],
  ['Tablet Portrait', 768, 1024],
  ['Tablet Landscape', 1024, 768],
];

async function waitState(page, predicate, label) {
  await page.waitForFunction(predicate, null, { timeout: 15000 }).catch(() => {
    throw new Error('timeout waiting for ' + label);
  });
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const results = [];
  let failed = false;

  for (const [name, width, height] of cases) {
    const context = await browser.newContext({
      viewport: { width, height },
      hasTouch: true,
      isMobile: width < 600,
      deviceScaleFactor: 1,
    });
    const page = await context.newPage();
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push('console:' + msg.text());
    });
    page.on('pageerror', err => errors.push('page:' + err.message));

    try {
      await page.goto('http://127.0.0.1:8000/p021-game/games/matchstick/?qa=1', { waitUntil: 'domcontentloaded' });
      await page.waitForSelector('canvas', { timeout: 15000 });
      await waitState(page, () => window.__MATCHSTICK_QA__?.ready === true, 'Godot ready');

      const top = await page.evaluate(() => window.__MATCHSTICK_QA__);
      if (top.build !== 'GAME-062-20261010') throw new Error('wrong build id');
      if (top.quality_target < 80) throw new Error('quality target below 80');
      if (top.screen !== 'top') throw new Error('initial screen is not top');
      if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)) {
        throw new Error('horizontal overflow at top');
      }

      await page.evaluate(() => { window.__MATCHSTICK_QA_COMMAND__ = 'start'; });
      await waitState(page, () => window.__MATCHSTICK_QA__?.screen === 'game' && !!window.__MATCHSTICK_QA__?.solution, 'game + solution');

      let state = await page.evaluate(() => window.__MATCHSTICK_QA__);
      if (state.rounds !== 1 || state.round !== 1) throw new Error('QA round setup invalid');
      const canvas = page.locator('canvas');

      await canvas.tap({ position: { x: state.solution.pick_x, y: state.solution.pick_y } });
      await waitState(page, () => window.__MATCHSTICK_QA__?.carry === true, 'match selected');

      state = await page.evaluate(() => window.__MATCHSTICK_QA__);
      await canvas.tap({ position: { x: state.solution.place_x, y: state.solution.place_y } });
      await waitState(page, () => window.__MATCHSTICK_QA__?.moved === true, 'match moved');

      await page.evaluate(() => { window.__MATCHSTICK_QA_COMMAND__ = 'reset'; });
      await waitState(page, () => window.__MATCHSTICK_QA__?.moved === false && window.__MATCHSTICK_QA__?.carry === false, 'reset');

      state = await page.evaluate(() => window.__MATCHSTICK_QA__);
      await canvas.tap({ position: { x: state.solution.pick_x, y: state.solution.pick_y } });
      await waitState(page, () => window.__MATCHSTICK_QA__?.carry === true, 'second selection');
      state = await page.evaluate(() => window.__MATCHSTICK_QA__);
      await canvas.tap({ position: { x: state.solution.place_x, y: state.solution.place_y } });
      await waitState(page, () => window.__MATCHSTICK_QA__?.moved === true, 'second move');

      await page.evaluate(() => { window.__MATCHSTICK_QA_COMMAND__ = 'check'; });
      await waitState(page, () => window.__MATCHSTICK_QA__?.screen === 'result', 'result');
      state = await page.evaluate(() => window.__MATCHSTICK_QA__);
      if (state.score !== 2) throw new Error('expected score 2, got ' + state.score);
      if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)) {
        throw new Error('horizontal overflow at result');
      }

      await page.evaluate(() => { window.__MATCHSTICK_QA_COMMAND__ = 'top'; });
      await waitState(page, () => window.__MATCHSTICK_QA__?.screen === 'top', 'return top');
      await page.evaluate(() => { window.__MATCHSTICK_QA_COMMAND__ = 'sound'; });
      await page.waitForTimeout(120);
      const sound = (await page.evaluate(() => window.__MATCHSTICK_QA__)).audio;
      if (sound !== 'SOUND 60%') throw new Error('volume cycle failed: ' + sound);

      if (errors.length) throw new Error(errors.join(' | '));
      results.push({ name, width, height, pass: true, score: 2, sound });
    } catch (error) {
      failed = true;
      results.push({ name, width, height, pass: false, error: String(error), errors });
    } finally {
      await context.close();
    }
  }

  await browser.close();
  console.log(JSON.stringify(results, null, 2));
  if (failed) process.exit(1);
})();
