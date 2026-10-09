import { chromium } from 'playwright';
import fs from 'node:fs';

const BASE_URL = process.env.BIBLIO_E2E_URL || 'http://127.0.0.1:4173/biblio/?review=1';
const outDir = 'biblio/test-results';
fs.mkdirSync(outDir, { recursive: true });

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function clickButton(page, text) {
  const button = page.getByRole('button', { name: text, exact: true });
  await button.waitFor({ state: 'visible' });
  await button.click();
}

async function waitScene(page, title) {
  await page.locator('.story-title', { hasText: title }).waitFor({ state: 'visible' });
}

async function nextScene(page) {
  const button = page.locator('.story-actions .btn').first();
  await button.waitFor({ state: 'visible' });
  await button.click();
}

async function solvePuzzle(page, correctLabel) {
  await clickButton(page, correctLabel);
  await page.getByText(/正解。次へ進めます。/).waitFor({ state: 'visible' });
}

async function seedScene(page, sceneKey, extra = {}) {
  await page.evaluate(({ sceneKey, extra }) => {
    const scene = sceneData(sceneKey);
    const base = normalizeProgressRecord({
      bookKey: 'cand-002',
      chapter: scene.chapter,
      scene: scene.scene,
      sceneKey,
      sceneTitle: scene.title,
      updatedAt: new Date().toISOString(),
      resumable: true,
      clueIds: extra.clueIds || ['CAND2-CARD-01'],
      questStates: extra.questStates || { 'CAND2-QMAIN-001': 'active' },
      triggerStates: extra.triggerStates || {},
      witnessStates: extra.witnessStates || {},
      timelineMode: 'present',
      currentLocationRole: extra.currentLocationRole || null
    });
    const patched = applySceneProgressPatch(base, scene);
    state.progressRecords = state.progressRecords.filter(x => x.bookKey !== 'cand-002');
    state.progressRecords.push(patched);
    persistProgress();
    state.book = 'cand-002';
    state.story = { chapter: scene.chapter, scene: scene.scene, sceneKey, title: scene.title };
    state.storyAdvance = { status:'idle', error:'', notice:'', mode:'success', lastRequestKey:'' };
    state.complete = false;
    state.completion = { status:'idle', error:'', record:null, lastRequestKey:'' };
    state.screen = 'U03';
    history.replaceState({ s:'U03' }, '', '#U03');
    render();
  }, { sceneKey, extra });
}

async function startFreshBook(page) {
  await page.evaluate(() => {
    localStorage.removeItem(PROGRESS_KEY);
    state.progressRecords = state.progressRecords.filter(x => x.bookKey !== 'cand-002');
    state.complete = false;
    state.completion = { status:'idle', error:'', record:null, lastRequestKey:'' };
    state.book = 'cand-002';
    state.screen = 'U01';
    history.replaceState({ s:'U01' }, '', '#U01');
    render();
  });
  const cand = page.locator('.book-card').filter({ hasText: '午後四時の消印' });
  await cand.waitFor({ state: 'visible' });
  await cand.click();
  await clickButton(page, 'このBookを始める');
  await waitScene(page, '差出人のない一枚');
}

async function assertPuzzleWrongRetry(page, wrong, hint, correct) {
  const next = page.locator('.story-actions .btn').first();
  assert(await next.isDisabled(), 'Puzzle must block progression before answer');
  await clickButton(page, wrong);
  await page.getByText(hint).waitFor({ state: 'visible' });
  assert(await next.isDisabled(), 'Wrong answer must keep progression blocked');
  await solvePuzzle(page, correct);
  assert(!(await next.isDisabled()), 'Correct answer must unlock progression');
}

async function resolveLocation(page, mode) {
  const label = mode === 'normal' ? '通常到着を確認' : '安全代替で進む';
  await clickButton(page, label);
  await page.getByText(mode === 'normal' ? /通常到着で進行条件を満たしました/ : /安全代替で進行条件を満たしました/).waitFor({ state: 'visible' });
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
const results = [];

async function runCase(id, fn) {
  try {
    await fn();
    results.push([id, 'PASS']);
    console.log(id + ' PASS');
  } catch (e) {
    results.push([id, 'FAIL']);
    console.error(id + ' FAIL', e);
    await page.screenshot({ path: outDir + '/' + id.toLowerCase() + '-failure.png', fullPage: true }).catch(() => {});
    throw e;
  }
}

try {
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: 'domcontentloaded' });
  await clickButton(page, 'Google でログイン');
  await page.waitForFunction(() => document.body.dataset.screen === 'U04');

  await runCase('E2E-01', async () => {
    await startFreshBook(page);
    await nextScene(page);
    await solvePuzzle(page, '時計盤上の4方向を示す方向キー'); await nextScene(page);
    await solvePuzzle(page, '駅・交通結節点相当'); await nextScene(page);
    await resolveLocation(page, 'normal'); await nextScene(page);
    await nextScene(page);
    await solvePuzzle(page, '月K-17/円 → 火M-04/三角 → 水R-12/葉 → 木S-08/四角 → 金T-21/星');
    await resolveLocation(page, 'normal'); await nextScene(page);
    await nextScene(page);
    await resolveLocation(page, 'normal'); await nextScene(page);
    await nextScene(page);
    await solvePuzzle(page, '説明書紛失が中止通知より前'); await nextScene(page);
    await resolveLocation(page, 'normal'); await nextScene(page);
    await solvePuzzle(page, 'Q02の順で重ね午後四時方向の線を延長する'); await nextScene(page);
    await nextScene(page);
    await solvePuzzle(page, '出典・同意資料を紛失し友人作品まで疑われる事態を避けるため'); await nextScene(page);
    await waitScene(page, '午後四時の先へ');
    await nextScene(page);
    await page.getByRole('heading', { name: 'Book Complete確認' }).waitFor({ state: 'visible' });
    await clickButton(page, '完了を確認する');
    await page.getByRole('heading', { name: 'Book Complete' }).waitFor({ state: 'visible' });
    const s = await page.evaluate(() => state.progressRecords.find(x => x.bookKey === 'cand-002'));
    assert(s.questStates['CAND2-QMAIN-001'] === 'complete', 'MAIN must be complete');
    assert(s.triggerStates['CAND2-BOOK-CLEAR'] === 'complete', 'Book Clear must be complete');
  });

  await runCase('E2E-02', async () => {
    await seedScene(page, 'cand2-ch07');
    const side = await page.evaluate(() => latestProgress('cand-002').questStates['CAND2-QSIDE-001']);
    assert(side !== 'complete', 'SIDE must begin incomplete');
    await nextScene(page);
    await waitScene(page, '四枚目の通り');
  });

  await runCase('E2E-03', async () => {
    await seedScene(page, 'cand2-ch07');
    await clickButton(page, 'SIDEを完了');
    await page.getByText(/SIDE補強：共同制作は複数人の素材を組み合わせる計画だった/).waitFor({ state: 'visible' });
    const side = await page.evaluate(() => latestProgress('cand-002').questStates['CAND2-QSIDE-001']);
    assert(side === 'complete', 'SIDE must complete');
    await nextScene(page);
    await waitScene(page, '四枚目の通り');
  });

  await runCase('E2E-04', async () => {
    await seedScene(page, 'cand2-ch15');
    await waitScene(page, '午後四時の先へ');
    assert(await page.getByText('追加エピローグ「光の帰り道」').count() === 0, 'Hidden epilogue must not show without HOBS');
    await nextScene(page);
    await page.getByRole('heading', { name: 'Book Complete確認' }).waitFor({ state: 'visible' });
  });

  await runCase('E2E-05', async () => {
    await seedScene(page, 'cand2-ch15', { clueIds:['CAND2-CARD-01','CAND2-HOBS-01','CAND2-HOBS-02'] });
    await page.getByText('追加エピローグ「光の帰り道」').waitFor({ state: 'visible' });
    const hidden = await page.evaluate(() => latestProgress('cand-002').questStates['CAND2-QHID-001']);
    assert(hidden === 'complete', 'HIDDEN must complete with both observations');
  });

  await runCase('E2E-06', async () => {
    await seedScene(page, 'cand2-ch15', { clueIds:['CAND2-CARD-01','CAND2-HOBS-01'] });
    assert(await page.getByText('追加エピローグ「光の帰り道」').count() === 0, 'Hidden epilogue must not show with one observation');
    const hidden = await page.evaluate(() => latestProgress('cand-002').questStates['CAND2-QHID-001']);
    assert(hidden !== 'complete', 'HIDDEN must remain incomplete with one observation');
  });

  await runCase('E2E-07', async () => {
    await seedScene(page, 'cand2-ch04');
    const before = await page.evaluate(() => latestProgress('cand-002').clueIds.includes('CAND2-CARD-02'));
    assert(!before, 'CARD-02 must be locked before arrival');
    await resolveLocation(page, 'normal');
    const after = await page.evaluate(() => latestProgress('cand-002').clueIds.includes('CAND2-CARD-02'));
    assert(after, 'CARD-02 must unlock on normal arrival');
  });

  await runCase('E2E-08', async () => {
    await seedScene(page, 'cand2-ch04');
    await resolveLocation(page, 'alternative');
    const p = await page.evaluate(() => latestProgress('cand-002'));
    assert(p.clueIds.includes('CAND2-CARD-02'), 'CARD-02 must unlock by safe alternative');
    assert(p.triggerStates['CAND2-L03-resolved'] === 'alternative', 'Alternative state must be recorded');
  });

  await runCase('E2E-09', async () => {
    await seedScene(page, 'cand2-ch04');
    await page.evaluate(() => go('U05'));
    await clickButton(page, '取得失敗');
    await page.getByText(/位置情報を利用できませんでした/).waitFor({ state: 'visible' });
    await clickButton(page, '安全な進め方を確認');
    await page.getByRole('heading', { name: '安全に続けるために' }).waitFor({ state: 'visible' });
    await clickButton(page, '代替進行');
    await waitScene(page, '本の余白');
  });

  await runCase('E2E-10', async () => {
    await seedScene(page, 'cand2-ch02');
    await assertPuzzleWrongRetry(page, '現実の16時まで待つ', 'Hint 1: 時間以外の読み方を考える', '時計盤上の4方向を示す方向キー');
  });

  await runCase('E2E-11', async () => {
    await seedScene(page, 'cand2-ch06');
    await clickButton(page, '金T-21/星 → 木S-08/四角 → 水R-12/葉 → 火M-04/三角 → 月K-17/円');
    await page.getByText('Hint 1: 曜日を月→金の順に並べる').waitFor({ state: 'visible' });
    await solvePuzzle(page, '月K-17/円 → 火M-04/三角 → 水R-12/葉 → 木S-08/四角 → 金T-21/星');
  });

  await runCase('E2E-12', async () => {
    await seedScene(page, 'cand2-ch10');
    await assertPuzzleWrongRetry(page, '木原証言が中止通知より後', 'Hint 1: 証言と文書を分ける', '説明書紛失が中止通知より前');
    await seedScene(page, 'cand2-ch12');
    await assertPuzzleWrongRetry(page, 'カードを入手順に重ね中央だけを見る', 'Hint 1: まず順序を確定', 'Q02の順で重ね午後四時方向の線を延長する');
    await seedScene(page, 'cand2-ch14');
    await assertPuzzleWrongRetry(page, '自分だけが展示をやめたかったから', 'Hint 1: 何を守ろうとしたかを見る', '出典・同意資料を紛失し友人作品まで疑われる事態を避けるため');
  });

  await runCase('E2E-13', async () => {
    await seedScene(page, 'cand2-ch12');
    let l07 = await page.evaluate(() => latestProgress('cand-002').triggerStates['CAND2-L07']);
    assert(l07 !== 'unlocked', 'L07 must start locked');
    await clickButton(page, 'カードを入手順に重ね中央だけを見る');
    l07 = await page.evaluate(() => latestProgress('cand-002').triggerStates['CAND2-L07']);
    assert(l07 !== 'unlocked', 'L07 must stay locked after wrong answer');
    await solvePuzzle(page, 'Q02の順で重ね午後四時方向の線を延長する');
    l07 = await page.evaluate(() => latestProgress('cand-002').triggerStates['CAND2-L07']);
    assert(l07 === 'unlocked', 'L07 must unlock after correct Q05');
    await nextScene(page);
    await waitScene(page, '返すための順路');
  });

  await runCase('E2E-14', async () => {
    for (const [sceneKey, title] of [['cand2-ch03','駅の輪郭'],['cand2-ch07','見落とされたスケッチ'],['cand2-ch11','五枚目の窓'],['cand2-ch14','中止した理由']]) {
      await seedScene(page, sceneKey, { clueIds:['CAND2-CARD-01','RESUME-MARK'], triggerStates:{'RESUME-STATE':'kept'} });
      await page.reload({ waitUntil:'domcontentloaded' });
      await page.waitForFunction(() => !!document.body.dataset.screen);
      if (await page.getByRole('button', { name:'Google でログイン', exact:true }).count()) {
        await clickButton(page, 'Google でログイン');
        await page.waitForFunction(() => document.body.dataset.screen === 'U04');
      }
      await page.evaluate(() => go('U01'));
      await clickButton(page, 'つづきから');
      await waitScene(page, title);
      const kept = await page.evaluate(() => {
        const p=latestProgress('cand-002'); return p && p.clueIds.includes('RESUME-MARK') && p.triggerStates['RESUME-STATE']==='kept';
      });
      assert(kept, 'Resume state must survive reload at ' + sceneKey);
    }
  });

  await runCase('E2E-15', async () => {
    await seedScene(page, 'cand2-ch14');
    await page.getByText(/展示を止めた意図と、説明から離れた責任は分けて記録する/).waitFor({ state:'visible' });
    await solvePuzzle(page, '出典・同意資料を紛失し友人作品まで疑われる事態を避けるため');
    await nextScene(page);
    await waitScene(page, '午後四時の先へ');
    await page.getByText(/再展示を強制せず、まず対話を再開する道を選ぶ/).waitFor({ state:'visible' });
  });

  await page.screenshot({ path: outDir + '/cand002-e2e15-pass.png', fullPage: true });
  console.log('CAND-002 ALL 15 E2E PASS ' + JSON.stringify(Object.fromEntries(results)));
} catch (error) {
  console.error(error);
  process.exitCode = 1;
} finally {
  await browser.close();
}
