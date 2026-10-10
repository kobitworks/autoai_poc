const { chromium } = require('playwright');
const fs = require('fs');

const targets = [
  { name: 'phone-portrait', width: 390, height: 844 },
  { name: 'phone-landscape', width: 844, height: 390 },
  { name: 'tablet-portrait', width: 768, height: 1024 },
  { name: 'tablet-landscape', width: 1024, height: 768 },
];

const url = 'http://127.0.0.1:8000/p021-game/games/jigsaw/?qa=1';

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function snapshot(page) {
  return await page.evaluate(() => window.__P021_JIGSAW || null);
}

async function command(page, action, value) {
  await page.evaluate(({ action, value }) => {
    window.__P021_JIGSAW_COMMAND = { action, value };
  }, { action, value });
}

(async () => {
  fs.mkdirSync('/tmp/p021-jigsaw-qa', { recursive: true });
  const browser = await chromium.launch({ headless: true });
  const report = [];

  try {
    for (let i = 0; i < targets.length; i += 1) {
      const target = targets[i];
      const context = await browser.newContext({
        viewport: { width: target.width, height: target.height },
        deviceScaleFactor: 1,
        isMobile: target.width <= 844,
        hasTouch: true,
      });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', err => errors.push('pageerror: ' + err.message));
      page.on('console', msg => {
        if (msg.type() === 'error') errors.push('console: ' + msg.text());
      });
      page.on('requestfailed', req => {
        const failure = req.failure();
        errors.push('request: ' + req.url() + ' ' + (failure ? failure.errorText : 'failed'));
      });

      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
      await page.waitForFunction(() => window.__P021_JIGSAW && window.__P021_JIGSAW.ready, null, { timeout: 120000 });

      let data = await snapshot(page);
      assert(data.build.indexOf('GAME-064') === 0, target.name + ': wrong build');
      assert(data.child_id === 'GAME-G029', target.name + ': wrong child id');
      assert(data.state === 'top', target.name + ': top screen not ready');

      const canvas = await page.locator('#canvas').boundingBox();
      assert(canvas && canvas.width > 200 && canvas.height > 200, target.name + ': canvas not visible');
      assert(canvas.x >= -2 && canvas.y >= -2, target.name + ': canvas starts outside viewport');
      assert(canvas.x + canvas.width <= target.width + 2, target.name + ': canvas overflows width');
      assert(canvas.y + canvas.height <= target.height + 2, target.name + ': canvas overflows height');

      await command(page, 'set_grid', 3 + (i % 5));
      await command(page, 'set_art', i % 4);
      await command(page, 'start');
      await page.waitForFunction(() => window.__P021_JIGSAW && window.__P021_JIGSAW.state === 'game', null, { timeout: 10000 });

      data = await snapshot(page);
      assert(data.piece_count === data.grid * data.grid, target.name + ': piece count mismatch');
      assert(data.board.w >= 200 && data.board.h >= 200, target.name + ': board too small');
      assert(data.board.x >= 0 && data.board.y >= 0, target.name + ': board outside viewport');
      assert(data.board.x + data.board.w <= target.width + 2, target.name + ': board width overflow');
      assert(data.board.y + data.board.h <= target.height + 2, target.name + ': board height overflow');

      await command(page, 'hint');
      await page.waitForFunction(() => window.__P021_JIGSAW && window.__P021_JIGSAW.hints >= 1, null, { timeout: 5000 });
      await command(page, 'audio');
      await command(page, 'solve');
      await page.waitForFunction(() => window.__P021_JIGSAW && window.__P021_JIGSAW.state === 'result', null, { timeout: 10000 });

      data = await snapshot(page);
      assert(data.solved === true, target.name + ': solve did not complete');
      assert(data.score > 0, target.name + ': non-positive score');
      assert(data.best >= data.score, target.name + ': best was not persisted');
      assert(data.moves >= data.grid, target.name + ': QA move count not populated');

      await page.screenshot({ path: '/tmp/p021-jigsaw-qa/' + target.name + '.png', fullPage: true });
      assert(errors.length === 0, target.name + ': runtime errors: ' + errors.join(' | '));

      report.push({
        viewport: target.name,
        width: target.width,
        height: target.height,
        grid: data.grid,
        art: data.art,
        score: data.score,
        best: data.best,
        moves: data.moves,
        hints: data.hints,
        board: data.board,
        status: 'PASS',
      });
      await context.close();
    }

    console.log(JSON.stringify({
      game: 'GAME-G029',
      task: 'GAME-064',
      quality_target: 84,
      general_public_quality: true,
      viewports: report,
    }, null, 2));
  } finally {
    await browser.close();
  }
})().catch(err => {
  console.error(err);
  process.exit(1);
});
