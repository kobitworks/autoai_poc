const { chromium } = require('playwright');

const cases = [
  ['Phone Portrait', 390, 844],
  ['Phone Landscape', 844, 390],
  ['Tablet Portrait', 768, 1024],
  ['Tablet Landscape', 1024, 768],
];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const results = [];
  let failed = false;

  for (const [name, width, height] of cases) {
    const page = await browser.newPage({ viewport: { width, height } });
    const errors = [];
    page.on('console', m => { if (m.type() === 'error') errors.push('console:' + m.text()); });
    page.on('pageerror', e => errors.push('page:' + e.message));

    try {
      await page.goto('http://127.0.0.1:8000/p021-game/games/matchstick/', { waitUntil: 'domcontentloaded' });
      if (await page.locator('#topLevel option').count() !== 3) throw new Error('difficulty options != 3');
      if (await page.locator('#topRounds option').count() !== 5) throw new Error('round options != 5');
      if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)) throw new Error('top horizontal overflow');

      await page.selectOption('#topLevel', 'hard');
      await page.selectOption('#topRounds', '1');
      await page.click('#btnStart');
      await page.waitForSelector('#screenGame:not(.hidden)', { timeout: 3000 });

      if (await page.locator('svg.digitSvg').count() < 2) throw new Error('digit count < 2');
      const game = await page.locator('.gameCard').boundingBox();
      if (!game || game.x < -1 || game.x + game.width > width + 2) throw new Error('game card outside viewport');

      let picked = false;
      const onCount = await page.locator('.seg.on').count();
      for (let i = 0; i < onCount; i++) {
        await page.locator('.seg.on').nth(i).click({ force: true });
        if (await page.locator('.seg.placeable').count()) { picked = true; break; }
      }
      if (!picked) throw new Error('no pickable match found');
      await page.locator('.seg.placeable').first().click({ force: true });
      if (await page.locator('#btnCheck').isDisabled()) throw new Error('move did not enable check');

      await page.click('#btnReset');
      if (!(await page.locator('#btnCheck').isDisabled())) throw new Error('reset did not disable check');
      if ((await page.locator('#carryPill').textContent()).trim() !== '棒：未選択') throw new Error('reset did not clear carry');

      await page.click('#btnSkip');
      await page.waitForSelector('#screenResult:not(.hidden)', { timeout: 3000 });
      if ((await page.locator('#finalScore').textContent()).trim() !== '0') throw new Error('unexpected one-round skip score');
      if (!/高いほど上位/.test(await page.locator('.scoreNote').textContent())) throw new Error('higher score semantics missing');
      if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 2)) throw new Error('result horizontal overflow');

      await page.click('#btnBackToTop');
      await page.waitForSelector('#screenTop:not(.hidden)', { timeout: 3000 });
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
