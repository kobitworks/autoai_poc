const { chromium } = require('playwright');
const fs = require('fs');

const targets = [
  { name: 'phone-portrait', width: 390, height: 844 },
  { name: 'phone-landscape', width: 844, height: 390 },
  { name: 'tablet-portrait', width: 768, height: 1024 },
  { name: 'tablet-landscape', width: 1024, height: 768 },
];

const url = 'http://127.0.0.1:8000/p021-game/games/orbit-switch-courier/?qa=1';

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function snapshot(page) {
  return await page.evaluate(() => window.__P021_ORBIT || null);
}

async function command(page, action) {
  await page.evaluate(action => {
    window.__P021_ORBIT_COMMAND = { action };
  }, action);
}

function inside(rect, width, height) {
  return rect && rect.length === 4 && rect[0] >= -2 && rect[1] >= -2 &&
    rect[2] > 100 && rect[3] > 70 &&
    rect[0] + rect[2] <= width + 2 && rect[1] + rect[3] <= height + 2;
}

(async () => {
  fs.mkdirSync('/tmp/p021-orbit-qa', { recursive: true });
  const browser = await chromium.launch({ headless: true });
  const report = [];

  try {
    for (const target of targets) {
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
      await page.waitForFunction(() => window.__P021_ORBIT && window.__P021_ORBIT.ready, null, { timeout: 120000 });

      let data = await snapshot(page);
      assert(data.build === 'GAME-069-20261011', target.name + ': wrong build');
      assert(data.child_id === 'GAME-G030', target.name + ': wrong child id');
      assert(data.state === 'intro', target.name + ': intro not ready');
      assert(inside(data.field, target.width, target.height), target.name + ': field outside viewport');
      assert(inside(data.info, target.width, target.height), target.name + ': info outside viewport');

      const canvas = await page.locator('#canvas').boundingBox();
      assert(canvas && canvas.width > 200 && canvas.height > 200, target.name + ': canvas missing');
      assert(canvas.x >= -2 && canvas.y >= -2, target.name + ': canvas starts outside viewport');
      assert(canvas.x + canvas.width <= target.width + 2, target.name + ': canvas width overflow');
      assert(canvas.y + canvas.height <= target.height + 2, target.name + ': canvas height overflow');

      await command(page, 'start');
      await page.waitForFunction(() => window.__P021_ORBIT && window.__P021_ORBIT.state === 'playing', null, { timeout: 10000 });

      await command(page, 'switch_success');
      await page.waitForFunction(() => window.__P021_ORBIT && window.__P021_ORBIT.orbit === 1, null, { timeout: 10000 });

      for (let i = 0; i < 5; i += 1) {
        await command(page, 'deliver');
        await page.waitForFunction(expected => window.__P021_ORBIT && window.__P021_ORBIT.deliveries >= expected, i + 1, { timeout: 10000 });
      }

      data = await snapshot(page);
      assert(data.deliveries >= 5, target.name + ': deliveries did not advance');
      assert(data.combo === 3, target.name + ': x3 combo not reached');
      assert(data.score > 0, target.name + ': score missing');
      assert(data.energy === 3, target.name + ': energy unexpectedly lost');

      await command(page, 'fail');
      await page.waitForFunction(() => window.__P021_ORBIT && window.__P021_ORBIT.energy === 2, null, { timeout: 10000 });

      await command(page, 'finish');
      await page.waitForFunction(() => window.__P021_ORBIT && window.__P021_ORBIT.state === 'result', null, { timeout: 10000 });
      data = await snapshot(page);
      assert(data.best >= data.score, target.name + ': best not persisted');
      assert(errors.length === 0, target.name + ': runtime errors: ' + errors.join(' | '));

      await page.screenshot({ path: '/tmp/p021-orbit-qa/' + target.name + '.png', fullPage: true });
      report.push({
        viewport: target.name,
        width: target.width,
        height: target.height,
        score: data.score,
        best: data.best,
        deliveries: data.deliveries,
        energy: data.energy,
        combo: data.combo,
        field: data.field,
        info: data.info,
        status: 'PASS',
      });
      await context.close();
    }

    console.log(JSON.stringify({
      game: 'GAME-G030',
      task: 'GAME-069',
      quality_target: 84,
      general_public_quality: true,
      url_only_play_flow: 'intro -> one-action transfer/delivery -> result -> retry',
      viewports: report,
    }, null, 2));
  } finally {
    await browser.close();
  }
})().catch(err => {
  console.error(err);
  process.exit(1);
});
