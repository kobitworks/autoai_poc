/* Text Matching Memory - game logic
 * - Smartphone portrait, max 6x5 (30 cards)
 * - Stage: character sets
 * - Tier: 1..5 defines string-length composition
 */
(function(){
  'use strict';

function goTopViaAd(){
  try{
    if(window.platform_sdk && typeof window.platform_sdk.back_to_top==='function'){
      window.platform_sdk.back_to_top();
      return true;
    }
  }catch(e){}
  return false;
}


  const $ = (id) => document.getElementById(id);

  
// --- text length (grapheme-ish) and font scaling ---
const textLen = (s) => {
  try { return Array.from(s).length; } catch(e){ return (s||'').length; }
};
const fontScaleFor = (s) => {
  const n = textLen(s || '');
  if(n <= 1) return 0.58;
  if(n === 2) return 0.46;
  if(n === 3) return 0.38;
  return 0.32;
};
function updateBoardCellMetric(){
  // Measure one card and store its min dimension as --cell (px)
  const any = boardEl && boardEl.querySelector('.cardBtn');
  if(!any) return;
  const r = any.getBoundingClientRect();
  const cell = Math.max(24, Math.floor(Math.min(r.width, r.height)));
  boardEl.style.setProperty('--cell', cell + 'px');
}
// Screens
  const topScreen = $('topScreen');
  const playScreen = $('playScreen');
  const resultScreen = $('resultScreen');

  // Controls
  const levelSelect = $('levelSelect');
  const stageSelect = $('stageSelect');
  const tierSelect  = $('tierSelect');
  const themeSelect = $('themeSelect');

  const startBtn = $('startBtn');
  const howtoBtn = $('howtoBtn');
  const retryBtn = $('retryBtn');
  const toTopBtn = $('toTopBtn');
  const againBtn = $('againBtn');
  const resultToTopBtn = $('resultToTopBtn');

  const howtoDialog = $('howtoDialog');
  const howtoCloseBtn = $('howtoCloseBtn');

  // HUD
  const hudTime = $('hudTime');
  const hudMiss = $('hudMiss');
  const hudTurn = $('hudTurn');
  const hudProg = $('hudProg');

  // Result
  const resTime = $('resTime');
  const resMiss = $('resMiss');
  const resTurn = $('resTurn');

  const boardEl = $('board');

  // Level mapping (cols x rows)
  const LEVELS = [
    { level: 1, cols: 4, rows: 3, cards: 12, pairs: 6 },
    { level: 2, cols: 5, rows: 4, cards: 20, pairs: 10 },
    { level: 3, cols: 6, rows: 4, cards: 24, pairs: 12 },
    { level: 4, cols: 6, rows: 5, cards: 30, pairs: 15 },
  ];

  // Tier -> lengths mix (probabilities)
  const TIER_MIX = {
    1: { p1: 1.00, p2: 0.00, p3: 0.00 },
    2: { p1: 0.70, p2: 0.30, p3: 0.00 },
    3: { p1: 0.00, p2: 1.00, p3: 0.00 },
    4: { p1: 0.00, p2: 0.80, p3: 0.20 },
    5: { p1: 0.00, p2: 0.00, p3: 1.00 },
  };

  // Settings (tweakable)
  const FLIP_BACK_MS = 600;

  // Repetition avoidance
  const SEED_KEY = 'text_matching_memory_recent_seeds';
  const MAX_SEEDS = 50;

  // Game state
  let state = null;
  let timer = null;

  // --------- utilities ---------
  function show(el){ el.classList.remove('hidden'); }
  function hide(el){ el.classList.add('hidden'); }

  function mmss(ms){
    const sec = Math.floor(ms/1000);
    const m = Math.floor(sec/60);
    const s = sec%60;
    return String(m).padStart(2,'0') + ':' + String(s).padStart(2,'0');
  }

  // Deterministic PRNG (LCG)
  function makeRng(seed){
    let x = seed >>> 0;
    return function(){
      // LCG parameters (Numerical Recipes)
      x = (1664525 * x + 1013904223) >>> 0;
      return x / 0x100000000;
    };
  }

  function shuffle(arr, rng){
    for(let i=arr.length-1;i>0;i--){
      const j = Math.floor(rng()*(i+1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  function getRecentSeeds(){
    try{
      const raw = localStorage.getItem(SEED_KEY);
      const a = raw ? JSON.parse(raw) : [];
      return Array.isArray(a) ? a : [];
    }catch(_){ return []; }
  }
  function saveSeed(seed){
    const seeds = getRecentSeeds();
    const next = [seed, ...seeds.filter(s => s !== seed)].slice(0, MAX_SEEDS);
    localStorage.setItem(SEED_KEY, JSON.stringify(next));
  }
  function newSeed(){
    const seeds = getRecentSeeds();
    let seed = (Date.now() ^ Math.floor(Math.random()*1e9)) >>> 0;
    for(let i=0;i<10;i++){
      if(!seeds.includes(seed)) break;
      seed = (seed + 2654435761) >>> 0;
    }
    return seed >>> 0;
  }

  // --------- charset / text generation ---------
  function buildStageOptions(){
    const stages = (window.TextMatchingMemoryCharset && window.TextMatchingMemoryCharset.STAGES) || [];
    stageSelect.innerHTML = '';
    stages.forEach(s => {
      const opt = document.createElement('option');
      opt.value = String(s.id);
      opt.textContent = `${s.id}. ${s.label}`;
      stageSelect.appendChild(opt);
    });
    if(stageSelect.options.length){
      stageSelect.value = '2';
    }
  }

  function pickLen(tierMix, rng){
    const r = rng();
    if(r < tierMix.p1) return 1;
    if(r < tierMix.p1 + tierMix.p2) return 2;
    return 3;
  }

  function generateUniqueTexts(pairCount, stageId, tier, rng){
    const pool = window.TextMatchingMemoryCharset.buildPool(stageId);
    const mix = TIER_MIX[tier] || TIER_MIX[2];

    const out = [];
    const used = new Set();

    // minimal length constraint for small pools (e.g., digits only)
    const minLenNeeded = (function(){
      // crude capacity estimate: poolSize^len >= pairCount * 2 (safety)
      const n = pool.length || 1;
      for(let len=1; len<=3; len++){
        if(Math.pow(n, len) >= pairCount*2) return len;
      }
      return 3;
    })();

    let guard = 0;
    while(out.length < pairCount && guard < 20000){
      guard++;
      let len = pickLen(mix, rng);
      if(len < minLenNeeded) len = minLenNeeded;

      let text = '';
      for(let i=0;i<len;i++){
        const ch = pool[Math.floor(rng()*pool.length)];
        text += ch;
      }
      if(used.has(text)) continue;
      used.add(text);
      out.push(text);
    }

    // fallback: if still not enough, force longer strings
    if(out.length < pairCount){
      while(out.length < pairCount && guard < 50000){
        guard++;
        let text = '';
        for(let i=0;i<3;i++){
          text += pool[Math.floor(rng()*pool.length)];
        }
        if(used.has(text)) continue;
        used.add(text);
        out.push(text);
      }
    }

    return out;
  }

  // --------- board rendering ---------
  function buildCards(texts, rng){
    // create 2 cards per text (pair)
    const cards = [];
    texts.forEach((t, i) => {
      const pairId = `p${i}`;
      cards.push({ id: `c${pairId}a`, pairId, text: t, state: 'hidden' });
      cards.push({ id: `c${pairId}b`, pairId, text: t, state: 'hidden' });
    });
    shuffle(cards, rng);
    return cards;
  }

  function renderBoard(){
    boardEl.innerHTML = '';
    boardEl.style.setProperty('--cols', state.cols);
    boardEl.style.setProperty('--rows', state.rows);
    boardEl.style.setProperty('--cardAspect', `${state.cols} / ${state.rows}`);

    // Auto compact HUD if rows are many (>=5)
    document.body.dataset.hud = (state.rows >= 5) ? 'compact' : 'standard';
    if(themeSelect && themeSelect.value === 'compact') document.body.dataset.hud = 'compact';

    state.cards.forEach((card) => {
      const btn = document.createElement('button');
      btn.className = 'cardBtn';
      btn.type = 'button';
      btn.dataset.cardId = card.id;
      btn.setAttribute('aria-label', 'card');
      btn.innerHTML = `
        <div class="cardInner">
          <div class="cardFace cardFront">?</div>
          <div class="cardFace cardBack"></div>
        </div>`;
      btn.addEventListener('click', onCardClick);
      boardEl.appendChild(btn);
    });

    syncBoardFaces();
    requestAnimationFrame(updateBoardCellMetric);
  }

  function syncBoardFaces(){
    const nodes = boardEl.querySelectorAll('.cardBtn');
    nodes.forEach((node) => {
      const id = node.dataset.cardId;
      const c = state.cardsById.get(id);
      const inner = node.querySelector('.cardInner');
      const back = node.querySelector('.cardBack');
      if(!c || !inner || !back) return;

      back.textContent = c.text;

      node.style.setProperty('--fsScale', String(fontScaleFor(c.text)));
      node.disabled = (c.state === 'matched' || state.lock);
      node.classList.toggle('isOpen', c.state === 'open' || c.state === 'matched');
      node.classList.toggle('isMatched', c.state === 'matched');
    });
  }

  // --------- game flow ---------
  function resetHud(){
    hudTime.textContent = '00:00';
    hudMiss.textContent = '0';
    hudTurn.textContent = '0';
    hudProg.textContent = `0/${state.pairs}`;
  }

  function startTimer(){
    stopTimer();
    state.startAt = Date.now();
    timer = setInterval(() => {
      hudTime.textContent = mmss(Date.now() - state.startAt);
    }, 250);
  }
  function stopTimer(){
    if(timer){ clearInterval(timer); timer = null; }
  }

  function onCardClick(ev){
    if(!state || state.lock) return;
    const id = ev.currentTarget.dataset.cardId;
    const card = state.cardsById.get(id);
    if(!card) return;
    if(card.state !== 'hidden') return;

    card.state = 'open';
    state.open.push(card);
    syncBoardFaces();

    if(state.open.length === 2){
      state.turn++;
      hudTurn.textContent = String(state.turn);

      const [a, b] = state.open;
      if(a.pairId === b.pairId){
        a.state = 'matched';
        b.state = 'matched';
        state.matchedPairs++;
        state.open = [];
        hudProg.textContent = `${state.matchedPairs}/${state.pairs}`;
        syncBoardFaces();

        if(state.matchedPairs === state.pairs){
          onClear();
        }
      }else{
        state.miss++;
        hudMiss.textContent = String(state.miss);
        state.lock = true;
        syncBoardFaces();
        setTimeout(() => {
          a.state = 'hidden';
          b.state = 'hidden';
          state.open = [];
          state.lock = false;
          syncBoardFaces();
        }, FLIP_BACK_MS);
      }
    }
  }

  function onClear(){
    stopTimer();
    const elapsed = Date.now() - state.startAt;

    resTime.textContent = mmss(elapsed);
    resMiss.textContent = String(state.miss);
    resTurn.textContent = String(state.turn);

    hide(playScreen);
    show(resultScreen);

    // optional platform integration
    try{
      if(window.platform_sdk && typeof window.platform_sdk.finish === 'function'){
        const score = Math.max(1, Math.floor(elapsed/1000));
        window.platform_sdk.finish(score, {
          miss: state.miss,
          turn: state.turn,
          level: state.level,
          stage: state.stageId,
          tier: state.tier
        });
      }
    }catch(_){}
  }

  function startGame({level, stageId, tier}){
    const lv = LEVELS.find(x => x.level === level) || LEVELS[0];
    const seed = newSeed();
    saveSeed(seed);
    const rng = makeRng(seed);

    const texts = generateUniqueTexts(lv.pairs, stageId, tier, rng);
    const cards = buildCards(texts, rng);

    state = {
      level,
      stageId,
      tier,
      seed,
      cols: lv.cols,
      rows: lv.rows,
      pairs: lv.pairs,
      cards,
      cardsById: new Map(cards.map(c => [c.id, c])),
      open: [],
      lock: false,
      miss: 0,
      turn: 0,
      matchedPairs: 0,
      startAt: 0,
    };

    resetHud();
    renderBoard();

    hide(topScreen);
    hide(resultScreen);
    show(playScreen);
    startTimer();
  }

  function backToTop(){
    stopTimer();
    state = null;
    hide(playScreen);
    hide(resultScreen);
    show(topScreen);
  }

  // --------- events ---------
  function bind(){
    buildStageOptions();

    startBtn.addEventListener('click', () => {
      const level = Number(levelSelect.value || 1);
      const stageId = Number(stageSelect.value || 1);
      const tier = Number(tierSelect.value || 2);
      startGame({level, stageId, tier});
    });

    retryBtn.addEventListener('click', () => {
      if(!state) return;
      startGame({ level: state.level, stageId: state.stageId, tier: state.tier });
    });

    againBtn.addEventListener('click', () => {
      if(!state) {
        // if state was cleared, reuse selects
        const level = Number(levelSelect.value || 1);
        const stageId = Number(stageSelect.value || 1);
        const tier = Number(tierSelect.value || 2);
        startGame({level, stageId, tier});
        return;
      }
      startGame({ level: state.level, stageId: state.stageId, tier: state.tier });
    });

    toTopBtn.addEventListener('click', backToTop);
    resultToTopBtn.addEventListener('click', backToTop);

    howtoBtn.addEventListener('click', () => howtoDialog.showModal());
    howtoCloseBtn.addEventListener('click', () => howtoDialog.close());

    themeSelect.addEventListener('change', () => {
      if(!state) return;
      renderBoard();
    });
  }

  // init
  document.addEventListener('DOMContentLoaded', bind);

window.addEventListener('resize', () => {
  if(!playScreen || playScreen.hidden) return;
  updateBoardCellMetric();
});
})();
