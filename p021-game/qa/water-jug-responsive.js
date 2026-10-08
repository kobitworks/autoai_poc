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
      await page.goto('http://127.0.0.1:8000/p021-game/games/water-jug/', { waitUntil: 'domcontentloaded' });

      if (await page.locator('#selDifficulty option').count() !== 3) throw new Error('difficulty options != 3');
      const top = await page.locator('.topCard').boundingBox();
      if (!top || top.x < -1 || top.x + top.width > width + 1) throw new Error('top card outside viewport');

      await page.selectOption('#selDifficulty', 'hard');
      await page.click('#btnStart');
      await page.waitForSelector('#screenGame:not(.hidden)', { timeout: 3000 });

      const board = await page.locator('.board').boundingBox();
      if (!board || board.x < -1 || board.x + board.width > width + 1) throw new Error('board outside viewport');

      const capA = Number(await page.locator('#capA').textContent());
      if (!Number.isFinite(capA) || capA <= 0) throw new Error('invalid capA');

      await page.click('#btnFillA');
      const valA = Number(await page.locator('#valA').textContent());
      if (valA !== capA) throw new Error('Fill A failed');

      await page.click('#btnPourAtoB');
      const moves = Number(await page.locator('#txtMoves').textContent());
      if (!Number.isFinite(moves) || moves < 2) throw new Error('move counter did not advance');

      await page.click('#btnReset');
      if ((await page.locator('#valA').textContent()).trim() !== '0') throw new Error('reset A failed');
      if ((await page.locator('#valB').textContent()).trim() !== '0') throw new Error('reset B failed');

      for (const selector of ['#btnFillA','#btnEmptyA','#btnPourAtoB','#btnFillB','#btnEmptyB','#btnPourBtoA','#btnReset','#btnNewPuzzle']) {
        const box = await page.locator(selector).boundingBox();
        if (!box || box.x < -1 || box.x + box.width > width + 1) throw new Error(selector + ' outside viewport');
      }

      if (errors.length) throw new Error(errors.join(' | '));
      results.push({ name, width, height, pass: true, capA, moves });
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
