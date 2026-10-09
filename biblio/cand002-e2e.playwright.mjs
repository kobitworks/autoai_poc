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
  assert(!(await button.isDisabled()), 'Next button must be enabled before advancing');
  await button.click();
}

async function solvePuzzle(page, correctLabel) {
  await clickButton(page, correctLabel);
  await page.getByText(/正解。次へ進めます。/).waitFor({ state: 'visible' });
}

async function resolveSafeLocation(page) {
  await clickButton(page, '安全代替で進む');
  await page.getByText(/安全代替で進行条件を満たしました/).waitFor({ state: 'visible' });
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });

try {
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => localStorage.clear());
  await page.reload({ waitUntil: 'domcontentloaded' });

  await clickButton(page, 'Google でログイン');
  await page.waitForFunction(() => document.body.dataset.screen === 'U04');
  await page.evaluate(() => go('U01'));

  const cand = page.locator('.book-card').filter({ hasText: '午後四時の消印' });
  await cand.waitFor({ state: 'visible' });
  await cand.click();
  await page.getByRole('heading', { name: '午後四時の消印' }).waitFor({ state: 'visible' });
  await clickButton(page, 'このBookを始める');
  await waitScene(page, '差出人のない一枚');

  // E2E-01: MAIN start + sequential chapter progression.
  await nextScene(page);
  await waitScene(page, '四時は時刻ではない');

  // E2E-10: Q01 wrong -> Hint -> retry -> correct.
  const blocked = page.locator('.story-actions .btn').first();
  assert(await blocked.isDisabled(), 'Q01 must block next chapter before answer');
  await clickButton(page, '現実の16時まで待つ');
  await page.getByText('Hint 1: 時間以外の読み方を考える').waitFor({ state: 'visible' });
  assert(await blocked.isDisabled(), 'Q01 must remain blocked after wrong answer');
  await solvePuzzle(page, '時計盤上の4方向を示す方向キー');
  assert(!(await blocked.isDisabled()), 'Q01 correct answer must unlock next chapter');
  await nextScene(page);

  // Q03
  await waitScene(page, '駅の輪郭');
  await solvePuzzle(page, '駅・交通結節点相当');
  await nextScene(page);

  // Location normal/safe contract: use safe alternative and confirm card unlock.
  await waitScene(page, '本の余白');
  let card2Before = await page.evaluate(() => latestProgress('cand-002').clueIds.includes('CAND2-CARD-02'));
  assert(!card2Before, 'CARD-02 must not unlock only by entering Chapter 4');
  await resolveSafeLocation(page);
  let card2After = await page.evaluate(() => latestProgress('cand-002').clueIds.includes('CAND2-CARD-02'));
  assert(card2After, 'CARD-02 must unlock after safe alternative resolution');
  await nextScene(page);

  await waitScene(page, '五枚の持ち主');
  await nextScene(page);

  await waitScene(page, '葉の向き');
  await solvePuzzle(page, '月K-17/円 → 火M-04/三角 → 水R-12/葉 → 木S-08/四角 → 金T-21/星');
  await resolveSafeLocation(page);
  await nextScene(page);

  // E2E-02: SIDE is optional and MAIN continues without completing it.
  await waitScene(page, '見落とされたスケッチ');
  await page.getByRole('button', { name: 'SIDEを完了' }).waitFor({ state: 'visible' });
  const sideBefore = await page.evaluate(() => latestProgress('cand-002').questStates['CAND2-QSIDE-001']);
  assert(sideBefore !== 'complete', 'SIDE must remain optional before advancing');
  await nextScene(page);
  await waitScene(page, '四枚目の通り');

  await resolveSafeLocation(page);
  await nextScene(page);

  await waitScene(page, '消えた説明書');
  await nextScene(page);

  // E2E-12 part 1: Q04 wrong -> Hint -> correct.
  await waitScene(page, '中止通知の書き方');
  await clickButton(page, '木原証言が中止通知より後');
  await page.getByText('Hint 1: 証言と文書を分ける').waitFor({ state: 'visible' });
  await solvePuzzle(page, '説明書紛失が中止通知より前');
  await nextScene(page);

  await waitScene(page, '五枚目の窓');
  await resolveSafeLocation(page);
  await nextScene(page);

  // E2E-13: L07 is locked before Q05 and unlocked only after correct answer.
  await waitScene(page, '重ねた絵葉書');
  const l07Before = await page.evaluate(() => latestProgress('cand-002').triggerStates['CAND2-L07']);
  assert(l07Before !== 'unlocked', 'L07 must be locked before Q05');
  await clickButton(page, 'カードを入手順に重ね中央だけを見る');
  await page.getByText('Hint 1: まず順序を確定').waitFor({ state: 'visible' });
  const l07Wrong = await page.evaluate(() => latestProgress('cand-002').triggerStates['CAND2-L07']);
  assert(l07Wrong !== 'unlocked', 'L07 must stay locked after wrong Q05 answer');
  await solvePuzzle(page, 'Q02の順で重ね午後四時方向の線を延長する');
  const l07After = await page.evaluate(() => latestProgress('cand-002').triggerStates['CAND2-L07']);
  assert(l07After === 'unlocked', 'L07 must unlock after correct Q05 answer');
  await nextScene(page);

  await waitScene(page, '返すための順路');
  await nextScene(page);

  // E2E-12 part 2: QF1 wrong -> Hint -> correct.
  await waitScene(page, '中止した理由');
  await clickButton(page, '自分だけが展示をやめたかったから');
  await page.getByText('Hint 1: 何を守ろうとしたかを見る').waitFor({ state: 'visible' });
  await solvePuzzle(page, '出典・同意資料を紛失し友人作品まで疑われる事態を避けるため');
  await nextScene(page);

  // E2E-04: HIDDEN not reached must not block MAIN completion.
  await waitScene(page, '午後四時の先へ');
  const hidden = await page.evaluate(() => latestProgress('cand-002').questStates['CAND2-QHID-001']);
  assert(hidden !== 'complete', 'HIDDEN must remain incomplete when optional observations were skipped');
  await nextScene(page);
  await page.getByRole('heading', { name: 'Book Complete確認' }).waitFor({ state: 'visible' });
  await clickButton(page, '完了を確認する');
  await page.getByRole('heading', { name: 'Book Complete' }).waitFor({ state: 'visible' });

  const finalState = await page.evaluate(() => {
    const p = latestProgress('cand-002');
    return {
      main: p.questStates['CAND2-QMAIN-001'],
      clear: p.triggerStates['CAND2-BOOK-CLEAR'],
      side: p.questStates['CAND2-QSIDE-001'],
      hidden: p.questStates['CAND2-QHID-001'],
      l07: p.triggerStates['CAND2-L07'],
      cards: p.clueIds.filter(x => /^CAND2-CARD-/.test(x))
    };
  });
  assert(finalState.main === 'complete', 'MAIN quest must complete');
  assert(finalState.clear === 'complete', 'Book Clear trigger must complete');
  assert(finalState.side !== 'complete', 'SIDE must remain optional in this path');
  assert(finalState.hidden !== 'complete', 'HIDDEN must remain optional in this path');
  assert(finalState.l07 === 'unlocked', 'L07 unlock must be retained');
  assert(finalState.cards.length === 5, 'All five postcard cards must be collected');

  await page.screenshot({ path: outDir + '/cand002-main-complete.png', fullPage: true });
  console.log('CAND-002 Headless E2E PASS', JSON.stringify(finalState));
} catch (error) {
  await page.screenshot({ path: outDir + '/cand002-failure.png', fullPage: true }).catch(() => {});
  console.error(error);
  process.exitCode = 1;
} finally {
  await browser.close();
}
