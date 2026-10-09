(() => {
  'use strict';

  const BEST_KEY = 'p021.matchstick.best.v1';

  const DIGIT_TO_MASK = {
    0: mask([0,1,2,3,4,5]),
    1: mask([1,2]),
    2: mask([0,1,6,4,3]),
    3: mask([0,1,2,3,6]),
    4: mask([5,6,1,2]),
    5: mask([0,5,6,2,3]),
    6: mask([0,5,4,3,2,6]),
    7: mask([0,1,2]),
    8: mask([0,1,2,3,4,5,6]),
    9: mask([0,1,2,3,5,6]),
  };
  const MASK_TO_DIGIT = Object.fromEntries(Object.entries(DIGIT_TO_MASK).map(([d,m]) => [String(m), Number(d)]));

  function mask(indices){
    let m = 0;
    for (const i of indices) m |= (1 << i);
    return m;
  }
  function isValidDigitMask(m){ return Object.prototype.hasOwnProperty.call(MASK_TO_DIGIT, String(m)); }
  function digitFromMask(m){ return MASK_TO_DIGIT[String(m)]; }
  function rndInt(min,maxInclusive){ return Math.floor(Math.random() * (maxInclusive - min + 1)) + min; }
  function choice(arr){ return arr[rndInt(0, arr.length - 1)]; }
  function evalExpr(a,op,b){
    if(op === '+') return a + b;
    if(op === '-') return a - b;
    if(op === '×') return a * b;
    throw new Error('unknown op');
  }
  function segIndicesOn(m){
    const out = [];
    for(let i=0;i<7;i++) if(m & (1 << i)) out.push(i);
    return out;
  }
  function parseEquation(str){
    const m = str.match(/^(\d{1,2})([+\-×])(\d{1,2})=(\d{1,2})$/);
    if(!m) return null;
    return {a:Number(m[1]),op:m[2],b:Number(m[3]),c:Number(m[4])};
  }
  function isEquationValid(str){
    const p = parseEquation(str);
    return !!p && evalExpr(p.a,p.op,p.b) === p.c;
  }

  function generatePuzzle(level){
    const ops = level === 'hard' ? ['+','-','×'] : ['+','-'];
    const maxA = level === 'easy' ? 9 : 99;
    const maxB = level === 'easy' ? 9 : 99;

    for(let tries=0; tries<2000; tries++){
      const op = choice(ops);
      let a = rndInt(0,maxA);
      let b = rndInt(0,maxB);
      if(op === '-' && a < b) [a,b] = [b,a];
      const c = evalExpr(a,op,b);
      if(c < 0 || c > 99) continue;
      if(level === 'easy' && (a > 9 || b > 9 || c > 9)) continue;

      const valid = String(a) + op + String(b) + '=' + String(c);
      const chars = valid.split('');
      const digitPositions = [];
      const masks = chars.map((ch,idx) => {
        if(ch >= '0' && ch <= '9'){
          digitPositions.push(idx);
          return DIGIT_TO_MASK[Number(ch)];
        }
        return null;
      });
      if(digitPositions.length < 2) continue;

      for(let t2=0; t2<200; t2++){
        const fromIdx = choice(digitPositions);
        const toIdx = choice(digitPositions);
        if(toIdx === fromIdx) continue;
        const fromMask = masks[fromIdx];
        const toMask = masks[toIdx];
        const seg = choice(segIndicesOn(fromMask));
        const newFrom = fromMask & ~(1 << seg);
        if(!isValidDigitMask(newFrom)) continue;
        if(toMask & (1 << seg)) continue;
        const newTo = toMask | (1 << seg);
        if(!isValidDigitMask(newTo)) continue;

        const brokenChars = [...chars];
        brokenChars[fromIdx] = String(digitFromMask(newFrom));
        brokenChars[toIdx] = String(digitFromMask(newTo));
        if(isEquationValid(brokenChars.join(''))) continue;

        const brokenMasks = masks.map((m,idx) => {
          if(m === null) return null;
          if(idx === fromIdx) return newFrom;
          if(idx === toIdx) return newTo;
          return m;
        });
        return {level,valid,chars:brokenChars,digitMasks:brokenMasks};
      }
    }
    return generatePuzzle('easy');
  }

  const $ = id => document.getElementById(id);
  const screenTop = $('screenTop');
  const screenGame = $('screenGame');
  const screenResult = $('screenResult');
  const topLevel = $('topLevel');
  const topRounds = $('topRounds');
  const btnStart = $('btnStart');
  const hudRound = $('hudRound');
  const hudScore = $('hudScore');
  const carryPill = $('carryPill');
  const equationEl = $('equation');
  const btnCheck = $('btnCheck');
  const btnReset = $('btnReset');
  const btnSkip = $('btnSkip');
  const msgEl = $('msg');
  const finalScore = $('finalScore');
  const finalMeta = $('finalMeta');
  const finalBest = $('finalBest');
  const btnRestart = $('btnRestart');
  const btnBackToTop = $('btnBackToTop');

  const state = {
    level:'easy', rounds:5, roundIdx:0, score:0,
    puzzle:null, carry:null, moved:false, originalMasks:null,
  };

  function showOnly(target){
    [screenTop,screenGame,screenResult].forEach(el => el.classList.toggle('hidden', el !== target));
    window.scrollTo({top:0,behavior:'instant'});
  }
  function setMsg(text,cls){
    msgEl.className = 'msg' + (cls ? ' ' + cls : '');
    msgEl.textContent = text || '';
  }
  function resetMove(){
    state.carry = null;
    state.moved = false;
    btnCheck.disabled = true;
    setCarryPill();
    setMsg('棒を1本だけ動かしてから「判定」を押してください。');
  }
  function setCarryPill(){
    carryPill.textContent = state.carry ? '棒：選択中' : '棒：未選択';
  }
  function bestId(){ return state.level + ':' + state.rounds; }
  function readBest(){
    try{
      const all = JSON.parse(localStorage.getItem(BEST_KEY) || '{}');
      return Number(all[bestId()] || 0);
    }catch(_){ return 0; }
  }
  function saveBest(score){
    try{
      const all = JSON.parse(localStorage.getItem(BEST_KEY) || '{}');
      const key = bestId();
      all[key] = Math.max(Number(all[key] || 0), score);
      localStorage.setItem(BEST_KEY, JSON.stringify(all));
      return Number(all[key]);
    }catch(_){ return score; }
  }

  function startGame(){
    state.level = topLevel.value;
    state.rounds = Number(topRounds.value);
    state.roundIdx = 0;
    state.score = 0;
    hudScore.textContent = '0';
    showOnly(screenGame);
    nextRound();
  }
  function nextRound(){
    state.roundIdx++;
    hudRound.textContent = state.roundIdx + '/' + state.rounds;
    state.puzzle = generatePuzzle(state.level);
    state.originalMasks = state.puzzle.digitMasks.map(m => m);
    resetMove();
    renderEquation();
  }
  function finishGame(){
    finalScore.textContent = String(state.score);
    finalMeta.textContent = '難易度: ' + state.level + ' / ラウンド: ' + state.rounds;
    finalBest.textContent = String(saveBest(state.score));
    showOnly(screenResult);
  }
  function renderEquation(){
    equationEl.innerHTML = '';
    state.puzzle.chars.forEach((ch,idx) => {
      const wrap = document.createElement('div');
      wrap.className = 'sym';
      if(ch >= '0' && ch <= '9') wrap.appendChild(buildDigitSvg(idx));
      else {
        const span = document.createElement('div');
        span.className = 'op';
        span.textContent = ch;
        wrap.appendChild(span);
      }
      equationEl.appendChild(wrap);
    });
  }
  function buildDigitSvg(pos){
    const ns = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(ns,'svg');
    svg.setAttribute('viewBox','0 0 80 140');
    svg.setAttribute('class','digitSvg');
    svg.dataset.pos = String(pos);
    const segs = [
      [[18,18],[62,18]],[[64,22],[64,64]],[[64,76],[64,118]],
      [[18,122],[62,122]],[[16,76],[16,118]],[[16,22],[16,64]],[[18,70],[62,70]]
    ];
    segs.forEach((points,segIdx) => {
      const line = document.createElementNS(ns,'line');
      line.setAttribute('x1',String(points[0][0]));
      line.setAttribute('y1',String(points[0][1]));
      line.setAttribute('x2',String(points[1][0]));
      line.setAttribute('y2',String(points[1][1]));
      line.classList.add('seg');
      line.dataset.pos = String(pos);
      line.dataset.seg = String(segIdx);
      line.setAttribute('role','button');
      line.setAttribute('aria-label','digit ' + pos + ' segment ' + (segIdx + 1));
      line.addEventListener('click',onSegClick);
      svg.appendChild(line);
    });
    paintDigit(pos,svg);
    return svg;
  }
  function paintDigit(pos,svgEl){
    const m = state.puzzle.digitMasks[pos];
    svgEl.querySelectorAll('.seg').forEach(segEl => {
      const s = Number(segEl.dataset.seg);
      const isOn = !!(m & (1 << s));
      segEl.classList.toggle('on',isOn);
      segEl.classList.toggle('carry',!!(state.carry && state.carry.fromPos === pos && state.carry.seg === s));
      segEl.classList.toggle('placeable',!!(state.carry && !state.moved && !isOn && canPlace(pos,s)));
    });
  }
  function repaintAllDigits(){
    equationEl.querySelectorAll('svg.digitSvg').forEach(svg => paintDigit(Number(svg.dataset.pos),svg));
  }
  function canPick(pos,seg){
    const m = state.puzzle.digitMasks[pos];
    return !!(m & (1 << seg)) && isValidDigitMask(m & ~(1 << seg));
  }
  function canPlace(pos,seg){
    const m = state.puzzle.digitMasks[pos];
    return !(m & (1 << seg)) && isValidDigitMask(m | (1 << seg));
  }
  function onSegClick(ev){
    if(state.moved) return;
    const segEl = ev.currentTarget;
    const pos = Number(segEl.dataset.pos);
    const seg = Number(segEl.dataset.seg);
    if(!state.carry){
      if(!canPick(pos,seg)) return;
      state.carry = {seg,fromPos:pos};
      setCarryPill();
      setMsg('青く光った置き場所をタップしてください。');
      repaintAllDigits();
      return;
    }
    if(!canPlace(pos,seg)) return;
    const from = state.carry.fromPos;
    const sourceSeg = state.carry.seg;
    state.puzzle.digitMasks[from] &= ~(1 << sourceSeg);
    state.puzzle.digitMasks[pos] |= (1 << seg);
    state.carry = null;
    state.moved = true;
    btnCheck.disabled = false;
    setCarryPill();
    setMsg('「判定」で結果を確認してください。');
    repaintAllDigits();
  }
  function currentEquationString(){
    const chars = [...state.puzzle.chars];
    for(let i=0;i<chars.length;i++){
      const m = state.puzzle.digitMasks[i];
      if(m === null || m === undefined) continue;
      if(chars[i] >= '0' && chars[i] <= '9') chars[i] = String(digitFromMask(m));
    }
    return chars.join('');
  }
  function resetPuzzle(){
    state.puzzle.digitMasks = state.originalMasks.map(m => m);
    resetMove();
    repaintAllDigits();
  }
  function applySkip(){
    state.score = Math.max(0,state.score - 1);
    hudScore.textContent = String(state.score);
    setMsg('スキップしました。正解例：' + state.puzzle.valid,'ng');
    setTimeout(() => state.roundIdx >= state.rounds ? finishGame() : nextRound(), 500);
  }
  function applyCheck(){
    const eq = currentEquationString();
    if(isEquationValid(eq)){
      state.score += 2;
      hudScore.textContent = String(state.score);
      setMsg('正解：' + eq,'ok');
      setTimeout(() => state.roundIdx >= state.rounds ? finishGame() : nextRound(), 500);
    }else{
      state.score = Math.max(0,state.score - 1);
      hudScore.textContent = String(state.score);
      setMsg('不正解：' + eq,'ng');
    }
  }

  btnStart.addEventListener('click',startGame);
  btnRestart.addEventListener('click',() => showOnly(screenTop));
  btnBackToTop.addEventListener('click',() => showOnly(screenTop));
  btnReset.addEventListener('click',resetPuzzle);
  btnSkip.addEventListener('click',applySkip);
  btnCheck.addEventListener('click',applyCheck);
  showOnly(screenTop);
})();
