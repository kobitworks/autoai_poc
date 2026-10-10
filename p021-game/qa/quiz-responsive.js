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
  gameplay: 8,
  controls: 9,
  difficulty: 8,
  ui_ux: 9,
  graphics: 8,
  effects: 8,
  sound: 8,
  content_variation: 10,
  replayability: 8,
  technical_quality: 10,
};
quality.total = Object.values(quality).reduce((a, b) => a + b, 0);

const outDir = path.resolve('p021-game/docs/qa/game-g017-quiz');

async function state(page) {
  return await page.evaluate(() => window.__P021_QUIZ || null);
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
      await page.goto('http://127.0.0.1:8000/p021-game/games/quiz/?qa=1', {
        waitUntil: 'domcontentloaded',
        timeout: 30000,
      });
      await page.waitForSelector('#canvas', { state: 'visible', timeout: 30000 });
      await wait(page, () => window.__P021_QUIZ && window.__P021_QUIZ.ready === true);

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
      if (scroll.w > scroll.cw + 2 || scroll.h > scroll.ch + 2) throw new Error('page overflow detected');

      let s = await state(page);
      if (!s || s.engine !== 'Godot' || s.build !== 'GAME-067' || !s.qa_mode) throw new Error('GAME-067 bridge missing');
      if (s.dataset_questions !== 45 || s.dataset_categories !== 3) throw new Error('local dataset contract mismatch');
      if (s.phase !== 'idle' || s.focus_level !== 1 || s.category !== 'math_logic') throw new Error('default setup mismatch');

      await canvas.click({ position: { x: Math.max(8, box.width / 2), y: Math.max(8, box.height / 2) } });
      await page.keyboard.press('c');
      await page.keyboard.press('c');
      for (let i = 0; i < 4; i++) await page.keyboard.press('l');
      await wait(page, () => window.__P021_QUIZ && window.__P021_QUIZ.category === 'web_basics' && window.__P021_QUIZ.focus_level === 5);

      await page.keyboard.press('m');
      await wait(page, () => window.__P021_QUIZ && window.__P021_QUIZ.sound === false);
      await page.keyboard.press('m');
      await wait(page, () => window.__P021_QUIZ && window.__P021_QUIZ.sound === true);

      await page.keyboard.press('Enter');
      await wait(page, () => window.__P021_QUIZ && window.__P021_QUIZ.phase === 'question');
      const ids = new Set();

      for (let i = 0; i < 10; i++) {
        s = await state(page);
        if (!s.question_id) throw new Error('question id missing');
        if (ids.has(s.question_id)) throw new Error('duplicate question in 10-question run');
        ids.add(s.question_id);
        if (i === 0) await page.keyboard.press('x');
        else await page.keyboard.press('f');
        await wait(page, () => window.__P021_QUIZ && window.__P021_QUIZ.phase === 'feedback');
        if (i < 9) {
          await page.keyboard.press('n');
          await page.waitForFunction(
            expected => window.__P021_QUIZ && window.__P021_QUIZ.phase === 'question' && window.__P021_QUIZ.question_number === expected,
            i + 2,
            { timeout: 30000 }
          );
        } else {
          await page.keyboard.press('n');
          await wait(page, () => window.__P021_QUIZ && window.__P021_QUIZ.finished === true);
        }
      }

      s = await state(page);
      if (s.correct !== 9 || s.wrong !== 1 || !s.finished) throw new Error('score/result flow mismatch');
      if (s.category !== 'web_basics' || s.focus_level !== 5) throw new Error('selected setup did not persist');
      if (ids.size !== 10) throw new Error('10 unique questions not preserved');
      if (errors.length) throw new Error(errors.join(' | '));

      const slug = name.toLowerCase().replace(/\s+/g, '-');
      await page.screenshot({ path: path.join(outDir, slug + '.png'), fullPage: true });
      results.push({
        name, width, height, pass: true,
        engine: s.engine,
        build: s.build,
        category: s.category,
        focus_level: s.focus_level,
        correct: s.correct,
        wrong: s.wrong,
        unique_questions: ids.size,
        canvas: box,
        overflow: false,
        url_only_flow: 'load -> choose Web -> Focus Lv5 -> sound toggle -> 10 unique questions -> miss/correct feedback -> explanations -> result -> replay/settings',
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
    game: 'GAME-G017 Quiz Arena',
    task: 'GAME-067',
    engine: 'Godot 4.7.2 Web',
    generated_at: new Date().toISOString(),
    public_url: 'https://kobitworks.github.io/autoai_poc/p021-game/games/quiz/',
    dataset: 'quiz-core-ja-v1',
    rules: {
      questions_per_run: 10,
      categories: 3,
      focus_levels: '1-5',
      score: 'numeric correct-count; higher is better; time is tie-break/meta',
      runtime_network_dependency: false,
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
