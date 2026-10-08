const { chromium } = require('playwright');

const cases = [
  ['Phone Portrait', 390, 844],
  ['Phone Landscape', 844, 390],
  ['Tablet Portrait', 768, 1024],
  ['Tablet Landscape', 1024, 768],
];

(async () => {
  const browser = await chromium.launch({ headless: true });
  let failed = false;
  const results = [];

  for (const [name, width, height] of cases) {
    const page = await browser.newPage({ viewport: { width, height } });
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push('console:' + m.text()); });
    page.on('pageerror', e => errors.push('page:' + e.message));

    try {
      await page.goto('http://127.0.0.1:8000/p021-game/games/switch-shortest/', { waitUntil: 'domcontentloaded' });
      if (await page.locator('#difficultySel option').count() !== 3) throw new Error('difficulty options != 3');
      const top = await page.locator('.topCard').boundingBox();
      if (!top || top.x < -1 || top.x + top.width > width + 1) throw new Error('top card outside viewport');

      await page.selectOption('#difficultySel', '12');
      if ((await page.locator('#topN').textContent()).trim() !== '12') throw new Error('Hard did not set 12 switches');
      await page.click('#startBtn');
      await page.waitForSelector('#playScreen:not(.hidden)', { timeout: 3000 });

      const card = await page.locator('.gameCard').boundingBox();
      if (!card || card.x < -1 || card.x + card.width > width + 1) throw new Error('game card outside viewport');
      if (await page.locator('#playRow .sw').count() !== 12) throw new Error('play switches != 12');

      await page.locator('#playRow .sw').first().click();
      if ((await page.locator('#hudMoves').textContent()).trim() !== '1') throw new Error('move counter did not advance');
      await page.click('#retryBtn');
      if ((await page.locator('#hudMoves').textContent()).trim() !== '0') throw new Error('retry did not reset moves');
      await page.locator('#playRow .sw').nth(1).focus();
      await page.keyboard.press('Enter');
      if ((await page.locator('#hudMoves').textContent()).trim() !== '1') throw new Error('keyboard activation failed');

      for (const selector of ['#retryBtn','#toTopBtn','#playRow']) {
        const box = await page.locator(selector).boundingBox();
        if (!box || box.x < -1 || box.x + box.width > width + 1) throw new Error(selector + ' outside viewport');
      }

      await page.click('#toTopBtn');
      await page.waitForSelector('#topScreen:not(.hidden)', { timeout: 3000 });
      if (errors.length) throw new Error(errors.join(' | '));
      results.push({ name, width, height, pass: true });
    } catch (e) {
      failed = true;
      results.push({ name, width, height, pass: false, error: String(e), errors });
    } finally {
      await page.close();
    }
  }

  await browser.close();
  console.log(JSON.stringify(results, null, 2));
  if (failed) process.exit(1);
})();