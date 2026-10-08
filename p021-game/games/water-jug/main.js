/* P021 adapter: no external Platform SDK dependency. */
window.platform_sdk = window.platform_sdk || {
  finish(score, meta){
    window.dispatchEvent(new CustomEvent('p021:game-finish',{detail:{game:'water_jug',score,meta}}));
  },
  back_to_top(){
    location.href='../../';
  }
};

(function(){
  'use strict';

  const $ = (id)=>document.getElementById(id);

  const els = {
    screenTop: $('screenTop'),
    screenGame: $('screenGame'),
    selDifficulty: $('selDifficulty'),
    btnStart: $('btnStart'),
    btnReset: $('btnReset'),
    btnNewPuzzle: $('btnNewPuzzle'),

    topCapA: $('topCapA'),
    topCapB: $('topCapB'),
    topTarget: $('topTarget'),
    topTarget2: $('topTarget2'),
    bestLine: $('bestLine'),

    capA: $('capA'),
    capB: $('capB'),
    target: $('target'),
    valA: $('valA'),
    valB: $('valB'),
    fillA: $('fillA'),
    fillB: $('fillB'),
    meterA: $('meterA'),
    meterB: $('meterB'),
    jugCardA: $('jugCardA'),
    jugCardB: $('jugCardB'),

    txtMoves: $('txtMoves'),
    txtTime: $('txtTime'),
    txtOptimal: $('txtOptimal'),
    goalHint: $('goalHint'),

    btnFillA: $('btnFillA'),
    btnEmptyA: $('btnEmptyA'),
    btnFillB: $('btnFillB'),
    btnEmptyB: $('btnEmptyB'),
    btnPourAtoB: $('btnPourAtoB'),
    btnPourBtoA: $('btnPourBtoA'),

    clearOverlay: $('clearOverlay'),
    clearMsg: $('clearMsg'),
    btnCloseOverlay: $('btnCloseOverlay'),
  };

  function clamp(n, min, max){
    return Math.max(min, Math.min(max, n));
  }

  function applyMeterHeights(){
    // Make the physical (visual) jug height proportional to capacity.
    // Width stays unified via flex; height difference makes capacity/amount more readable.
    const maxCap = Math.max(game.capA || 1, game.capB || 1);
    const vw = Math.max(320, Math.min(window.innerWidth || 640, 960));

    // Tune for mobile first: keep within viewport without forcing scroll.
    const baseMin = (vw <= 380) ? 120 : (vw <= 520 ? 140 : 160);
    const baseMax = (vw <= 380) ? 190 : (vw <= 520 ? 220 : 260);

    const hA = clamp(Math.round(baseMin + (game.capA / maxCap) * (baseMax - baseMin)), 110, 280);
    const hB = clamp(Math.round(baseMin + (game.capB / maxCap) * (baseMax - baseMin)), 110, 280);

    if(els.meterA) els.meterA.style.setProperty('--meter-h', hA + 'px');
    if(els.meterB) els.meterB.style.setProperty('--meter-h', hB + 'px');
  }

  const LS_KEY = 'water_jug.best.v1';

  function gcd(a,b){ while(b){ const t=a%b; a=b; b=t; } return Math.abs(a); }

  function rngInt(min, max){
    return Math.floor(Math.random()*(max-min+1))+min;
  }

  function isSolvable(capA, capB, target){
    if(target<0) return false;
    if(target>Math.max(capA, capB)) return false;
    return target % gcd(capA, capB) === 0;
  }

  function genPuzzle(diff){
    const ranges = {
      easy:   {a:[3,8],  b:[4,10]},
      normal: {a:[5,12], b:[6,16]},
      hard:   {a:[8,20], b:[10,28]},
    }[diff] || {a:[5,12], b:[6,16]};

    for(let i=0;i<500;i++){
      let capA = rngInt(ranges.a[0], ranges.a[1]);
      let capB = rngInt(ranges.b[0], ranges.b[1]);
      if(capA === capB) continue;

      // keep distinct and not too close (visual + gameplay)
      if(Math.abs(capA-capB) <= 1) continue;

      const g = gcd(capA, capB);
      const maxT = Math.max(capA, capB);

      // pick a target that's solvable and non-trivial
      const candidates = [];
      for(let t=g; t<=maxT; t+=g){
        if(t===capA || t===capB) continue;
        candidates.push(t);
      }
      if(!candidates.length) continue;
      const target = candidates[rngInt(0, candidates.length-1)];

      // compute optimal steps with BFS; ensure it is not too short (boring) nor too long (frustrating)
      const opt = shortestSteps(capA, capB, target);
      if(opt == null) continue;
      const minOk = (diff==='easy') ? 3 : (diff==='normal' ? 4 : 5);
      const maxOk = (diff==='easy') ? 10 : (diff==='normal' ? 16 : 22);
      if(opt < minOk || opt > maxOk) continue;

      return {capA, capB, target, optimal: opt};
    }

    // fallback (classic 3-5 -> 4)
    return {capA:3, capB:5, target:4, optimal: shortestSteps(3,5,4) || 6};
  }

  function stateKey(a,b){ return a + ',' + b; }

  function shortestSteps(capA, capB, target){
    // BFS over states (a,b)
    const q = [];
    const seen = new Set();
    q.push({a:0,b:0,d:0});
    seen.add(stateKey(0,0));

    while(q.length){
      const cur = q.shift();
      if(cur.a === target || cur.b === target) return cur.d;

      const nexts = [];

      // fill
      nexts.push({a:capA, b:cur.b});
      nexts.push({a:cur.a, b:capB});

      // empty
      nexts.push({a:0, b:cur.b});
      nexts.push({a:cur.a, b:0});

      // pour A->B
      {
        const space = capB - cur.b;
        const moved = Math.min(cur.a, space);
        nexts.push({a:cur.a - moved, b:cur.b + moved});
      }
      // pour B->A
      {
        const space = capA - cur.a;
        const moved = Math.min(cur.b, space);
        nexts.push({a:cur.a + moved, b:cur.b - moved});
      }

      for(const n of nexts){
        const k = stateKey(n.a, n.b);
        if(seen.has(k)) continue;
        seen.add(k);
        q.push({a:n.a, b:n.b, d:cur.d+1});
      }
    }
    return null;
  }

  const game = {
    diff: 'normal',
    capA: 3,
    capB: 5,
    target: 4,
    optimal: null,
    a: 0,
    b: 0,
    moves: 0,
    t0: 0,
    timer: null,
    finished: false,
  };

  function loadBest(){
    try{
      return JSON.parse(localStorage.getItem(LS_KEY) || '{}') || {};
    }catch(_){
      return {};
    }
  }
  function saveBest(best){
    localStorage.setItem(LS_KEY, JSON.stringify(best));
  }

  function formatBestLine(){
    const best = loadBest();
    const rec = best[game.diff];
    if(!rec){
      if(els.bestLine) els.bestLine.textContent = 'Best: まだ記録がありません';
      return;
    }
    if(els.bestLine) els.bestLine.textContent = `Best: ${rec.moves}手 / ${(rec.time_ms/1000).toFixed(1)}s（A${rec.capA}, B${rec.capB}, 目標${rec.target}）`;
  }

  
function showClearOverlay(message){
  if(!els.clearOverlay) return;
  if(els.clearMsg) els.clearMsg.textContent = message || '';
  els.clearOverlay.classList.remove('hidden');
}

function hideClearOverlay(){
  if(!els.clearOverlay) return;
  els.clearOverlay.classList.add('hidden');
}

function updatePreview(){
    game.diff = els.selDifficulty.value || 'normal';
    const p = genPuzzle(game.diff);
    if(els.topCapA) els.topCapA.textContent = String(p.capA);
    if(els.topCapB) els.topCapB.textContent = String(p.capB);
    if(els.topTarget) els.topTarget.textContent = String(p.target);
    if(els.topTarget2) els.topTarget2.textContent = String(p.target);

    // store preview as pending puzzle
    game.capA = p.capA; game.capB = p.capB; game.target = p.target; game.optimal = p.optimal;
    formatBestLine();
  }

  function showTop(){
    els.screenTop.classList.remove('hidden');
    els.screenGame.classList.add('hidden');
    updatePreview();
  }

  function showGame(){
    els.screenTop.classList.add('hidden');
    els.screenGame.classList.remove('hidden');
  }

  function resetState(keepPuzzle=true){
    game.a = 0; game.b = 0;
    game.moves = 0;
    game.finished = false;

    els.txtMoves.textContent = '0';
    els.txtTime.textContent = '0.0';
    els.goalHint.textContent = 'いずれかで目標量を作ればクリアです。';
    if(!keepPuzzle){
      const p = genPuzzle(game.diff);
      game.capA = p.capA; game.capB = p.capB; game.target = p.target; game.optimal = p.optimal;
    }

    els.capA.textContent = String(game.capA);
    els.capB.textContent = String(game.capB);
    els.target.textContent = String(game.target);
    els.txtOptimal.textContent = (game.optimal == null ? '-' : String(game.optimal));

    applyMeterHeights();

    render();

    if(game.timer) clearInterval(game.timer);
    game.t0 = performance.now();
    game.timer = setInterval(()=>{
      const ms = performance.now() - game.t0;
      els.txtTime.textContent = (ms/1000).toFixed(1);
    }, 100);
  }

  function render(){
    els.valA.textContent = String(game.a);
    els.valB.textContent = String(game.b);
    els.fillA.style.height = (game.capA ? (game.a / game.capA * 100) : 0) + '%';
    els.fillB.style.height = (game.capB ? (game.b / game.capB * 100) : 0) + '%';
  }

  function bumpMove(){
    if(game.finished) return;
    game.moves++;
    els.txtMoves.textContent = String(game.moves);
  }

  function checkFinish(){
    if(game.finished) return;
    if(game.a === game.target || game.b === game.target){
      game.finished = true;
      if(game.timer) clearInterval(game.timer);
      const timeMs = Math.max(0, Math.round(performance.now() - game.t0));
      const msg = `クリア！ ${game.moves}手 / ${(timeMs/1000).toFixed(1)}s`;
      els.goalHint.textContent = msg;
      showClearOverlay(msg);

      // save best (moves prioritized, then time)
      const best = loadBest();
      const cur = {moves: game.moves, time_ms: timeMs, capA: game.capA, capB: game.capB, target: game.target};
      const prev = best[game.diff];
      const better = (!prev) ||
        (cur.moves < prev.moves) ||
        (cur.moves === prev.moves && cur.time_ms < prev.time_ms);
      if(better){
        best[game.diff] = cur;
        saveBest(best);
      }

      // report to platform (lower is better)
      try{
        if(window.platform_sdk && typeof window.platform_sdk.finish === 'function'){
          window.platform_sdk.finish(game.moves, {
            moves: game.moves,
            time_ms: timeMs,
            optimal: game.optimal,
            capA: game.capA,
            capB: game.capB,
            target: game.target,
            difficulty: game.diff
          });
        }
      }catch(_){}

      formatBestLine();
    }
  }

  function doFill(which){
    if(game.finished) return;
    if(which==='A'){
      if(game.a === game.capA) return;
      game.a = game.capA;
    }else{
      if(game.b === game.capB) return;
      game.b = game.capB;
    }
    bumpMove(); render(); checkFinish();
  }

  function doEmpty(which){
    if(game.finished) return;
    if(which==='A'){
      if(game.a === 0) return;
      game.a = 0;
    }else{
      if(game.b === 0) return;
      game.b = 0;
    }
    bumpMove(); render(); checkFinish();
  }

  function doPour(dir){
    if(game.finished) return;
    if(dir==='AtoB'){
      if(game.a===0 || game.b===game.capB) return;
      const space = game.capB - game.b;
      const moved = Math.min(game.a, space);
      game.a -= moved; game.b += moved;
    }else{
      if(game.b===0 || game.a===game.capA) return;
      const space = game.capA - game.a;
      const moved = Math.min(game.b, space);
      game.b -= moved; game.a += moved;
    }
    bumpMove(); render(); checkFinish();
  }

  function bind(){
    els.selDifficulty.addEventListener('change', updatePreview);
    els.btnStart.addEventListener('click', ()=>{
      // use preview puzzle already set on game.*
      hideClearOverlay();
      showGame();
      resetState(true);
    });

    els.btnReset.addEventListener('click', ()=>{ hideClearOverlay(); resetState(true); });
    els.btnNewPuzzle.addEventListener('click', ()=>{
      hideClearOverlay();
      resetState(false);
    });

    els.btnFillA.addEventListener('click', ()=>doFill('A'));
    els.btnEmptyA.addEventListener('click', ()=>doEmpty('A'));
    els.btnFillB.addEventListener('click', ()=>doFill('B'));
    els.btnEmptyB.addEventListener('click', ()=>doEmpty('B'));
    els.btnPourAtoB.addEventListener('click', ()=>doPour('AtoB'));
    els.btnPourBtoA.addEventListener('click', ()=>doPour('BtoA'));

    if(els.btnCloseOverlay) els.btnCloseOverlay.addEventListener('click', hideClearOverlay);
    if(els.clearOverlay) els.clearOverlay.addEventListener('click', (e)=>{ if(e.target === els.clearOverlay) hideClearOverlay(); });
  }

  // init
  bind();
  showTop();

  // keep meter heights reasonable on orientation changes
  window.addEventListener('resize', ()=>{
    if(!els.screenGame.classList.contains('hidden')) applyMeterHeights();
  });
})();
