(() => {
  'use strict';
  const BEST_KEY='p021.game-g014.best';
  window.platform_sdk=window.platform_sdk||{
    finish(score,meta){
      try{
        const key=String(meta && meta.difficulty || 'normal');
        const all=JSON.parse(localStorage.getItem(BEST_KEY)||'{}');
        if(all[key]==null || Number(score)<Number(all[key])){all[key]=Number(score);localStorage.setItem(BEST_KEY,JSON.stringify(all));}
      }catch(_){}
      window.dispatchEvent(new CustomEvent('p021:game-finish',{detail:{game:'switch_shortest',score,meta}}));
    },
    back_to_top(){location.href='../../';}
  };

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

  const topScreen = $('topScreen');
  const playScreen = $('playScreen');

  const difficultySel = $('difficultySel');
  const topN = $('topN');
  const topBest = $('topBest');
  const topGoalRow = $('topGoalRow');
  const topStartRow = $('topStartRow');
  const startBtn = $('startBtn');

  const hudMoves = $('hudMoves');
  const hudBest = $('hudBest');
  const hudN = $('hudN');
  const goalRow = $('goalRow');
  const playRow = $('playRow');
  const hintText = $('hintText');
  const retryBtn = $('retryBtn');
  const toTopBtn = $('toTopBtn');

  let n = 10;
  let start = [];
  let goal = [];
  let cur = [];
  let best = null;
  let moves = 0;
  let finished = false;

  let playCells = []; // [{el, i}]

  function show(el){ el.classList.remove('hidden'); }
  function hide(el){ el.classList.add('hidden'); }

  function iconHtml(isOn){
    return '<span class="switchIcon" aria-hidden="true"></span>';
  }

  function renderStaticRow(container, arr){
    container.innerHTML = '';
    container.style.setProperty('--cols', String(arr.length));
    for(let i=0;i<arr.length;i++){
      const sw = document.createElement('span');
      sw.className = 'sw ' + (arr[i] ? 'on':'off');
      sw.innerHTML = iconHtml(arr[i]);
      sw.setAttribute('aria-hidden','true');
      container.appendChild(sw);
    }
  }

  function setSwitchVisual(el, isOn){
    el.classList.toggle('on', isOn);
    el.classList.toggle('off', !isOn);
    el.innerHTML = iconHtml(isOn);
  }

  function buildPlayRow(container, arr){
    container.innerHTML = '';
    container.style.setProperty('--cols', String(arr.length));
    playCells = [];

    for(let i=0;i<arr.length;i++){
      const sw = document.createElement('span');
      sw.className = 'sw ' + (arr[i] ? 'on':'off');
      sw.innerHTML = iconHtml(arr[i]);
      sw.setAttribute('role','button');
      sw.setAttribute('tabindex','0');
      sw.setAttribute('aria-label', `switch ${i+1}`);

      sw.addEventListener('click', () => onPress(i));
      sw.addEventListener('keydown', (e) => {
        if(e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onPress(i); }
      });

      container.appendChild(sw);
      playCells.push(sw);
    }
  }

  function refreshAt(indices){
    for(const i of indices){
      if(i<0 || i>=cur.length) continue;
      const el = playCells[i];
      if(el) setSwitchVisual(el, cur[i]);
    }
  }

  function xorToggleAt(arr, idx){
    if(idx<0 || idx>=arr.length) return;
    arr[idx] = !arr[idx];
  }

  function applyMove(idx){
    xorToggleAt(cur, idx);
    xorToggleAt(cur, idx-1);
    xorToggleAt(cur, idx+1);
  }

  function arrToMask(arr){
    let m = 0;
    for(let i=0;i<arr.length;i++){
      if(arr[i]) m |= (1<<i);
    }
    return m;
  }

  function shortestMoves(startArr, goalArr){
    const len = startArr.length;
    const startM = arrToMask(startArr);
    const goalM = arrToMask(goalArr);
    if(startM === goalM) return 0;

    const q = [startM];
    const dist = new Map();
    dist.set(startM, 0);

    const flipMask = new Array(len).fill(0).map((_,i)=>{
      let m = 0;
      m |= (1<<i);
      if(i>0) m |= (1<<(i-1));
      if(i<len-1) m |= (1<<(i+1));
      return m;
    });

    for(let qi=0; qi<q.length; qi++){
      const m = q[qi];
      const d = dist.get(m);
      for(let i=0;i<len;i++){
        const nm = m ^ flipMask[i];
        if(dist.has(nm)) continue;
        const nd = d + 1;
        if(nm === goalM) return nd;
        dist.set(nm, nd);
        q.push(nm);
      }
    }
    return null;
  }

  function randomBool(){ return Math.random() < 0.5; }

  function generatePuzzle(){
    n = parseInt(difficultySel.value, 10);

    goal = new Array(n).fill(false).map(randomBool);
    start = new Array(n).fill(false).map(randomBool);

    let guard = 0;
    while(guard < 20 && start.every((v,i)=>v===goal[i])){
      start = new Array(n).fill(false).map(randomBool);
      guard++;
    }

    best = shortestMoves(start, goal);

    topN.textContent = String(n);
    topBest.textContent = (best===null) ? '-' : String(best);

    renderStaticRow(topGoalRow, goal);
    renderStaticRow(topStartRow, start);
  }

  function syncHud(){
    hudMoves.textContent = String(moves);
    hudBest.textContent = (best===null) ? '-' : String(best);
    hudN.textContent = String(n);
  }

  function checkFinish(){
    const ok = cur.every((v,i)=>v===goal[i]);
    if(!ok){
      hintText.textContent = '';
      return;
    }
    finished = true;
    hintText.textContent = `クリア！ 手数: ${moves}（最短: ${best ?? '-'}）`;

    try{
      if(window.platform_sdk && typeof window.platform_sdk.finish === 'function'){
        window.platform_sdk.finish(moves, {
          moves,
          optimal: best,
          switches: n,
          difficulty: n
        });
      }
    }catch(_){}
  }

  function onPress(idx){
    if(finished) return;
    applyMove(idx);
    moves++;
    syncHud();
    refreshAt([idx-1, idx, idx+1]);
    checkFinish();
  }

  function startGame(){
    moves = 0;
    finished = false;
    cur = start.slice();

    hide(topScreen);
    show(playScreen);

    syncHud();
    renderStaticRow(goalRow, goal);
    buildPlayRow(playRow, cur);
    hintText.textContent = '';
  }

  function retry(){
    moves = 0;
    finished = false;
    cur = start.slice();
    syncHud();
    buildPlayRow(playRow, cur);
    hintText.textContent = '';
  }

  function backToTop(){
    hide(playScreen);
    show(topScreen);
    hintText.textContent = '';
    generatePuzzle();
  }

  function init(){
    difficultySel.addEventListener('change', generatePuzzle);
    startBtn.addEventListener('click', startGame);
    retryBtn.addEventListener('click', retry);
    toTopBtn.addEventListener('click', backToTop);
    generatePuzzle();
  }

  document.addEventListener('DOMContentLoaded', init);
})();
