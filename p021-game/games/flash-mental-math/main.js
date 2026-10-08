

function goTopViaAd(){
  try{
    if(window.platform_sdk && typeof window.platform_sdk.back_to_top==='function'){
      window.platform_sdk.back_to_top();
      return true;
    }
  }catch(e){}
  return false;
}
/* flash_mental_math main */
(function(){
  const $ = (sel)=>document.querySelector(sel);

  // Screens
  const screenTop = $('#screenTop');
  const screenGame = $('#screenGame');

  // Top inputs
  const stageSelect = $('#stageSelect');
  const levelSelect = $('#levelSelect');
  const roundSelect = $('#roundSelect');
  const btnStart = $('#btnStart');
  const btnBackTop = $('#btnBackTop');

  // Game UI
  const hudRound = $('#hudRound');
  const hudStage = $('#hudStage');
  const arena = $('#arena');
  const flashToken = $('#flashToken');
  const keypadCard = $('#keypadCard');
  const answerDisplay = $('#answerDisplay');
  const btnBackGame = $('#btnBackGame');

  // Config
  const STAGES = [
    {id:1, name:'Stage 1（基礎 / 加算のみ）', ops:['+'], trap:false},
    {id:2, name:'Stage 2（妨害 / 加算 + トラップ）', ops:['+'], trap:true},
    {id:3, name:'Stage 3（計算 / 加減算）', ops:['+','-'], trap:false},
    {id:4, name:'Stage 4（耐性 / 加減算 + トラップ）', ops:['+','-'], trap:true},
    {id:5, name:'Stage 5（最難 / 四則 + トラップ）', ops:['+','-','×','÷'], trap:true},
  ];

  const TRAP_POOLS = {
    alphabet: 'ABCDEFGHJKLMNPQRSTUVWXYZ'.split(''), // I,O,Q removed (similar)
    hiragana: 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん'.split(''),
    katakana: 'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン'.split(''),
    // NOTE: JIS第一水準限定の「紛らわしい」固定リストは後で拡充可能。
    // 現段階では、実用上問題になりにくい範囲の代表例を入れておく。
    kanji: '未末土士口日目自木本千干申甲白百右石'.split('')
  };

  const LEVELS = [1,2,3,4,5];

  // Defaults
  let config = { stage:1, level:1, rounds:10 };

  // State
  let state = {
    round: 1,
    totalRounds: 10,
    correct: 0,
    sumAnswer: 0,
    input: '',
    startTs: 0,
    answerStartTs: 0,
    tokens: [],
  };

  function randInt(min, max){
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  function sleep(ms){
    if(new URLSearchParams(location.search).get('qa') === '1') ms = Math.min(ms, 20);
    return new Promise(r=>setTimeout(r, ms));
  }

  function show(el){ el.classList.remove('is-hidden'); }
  function hide(el){ el.classList.add('is-hidden'); }

  function setScreen(which){
    if(which === 'top'){
      show(screenTop); hide(screenGame);
    }else{
      hide(screenTop); show(screenGame);
    }
  }

  function tokenText(tok){
    return tok.display;
  }

  function pickTrapPool(stageId, level){
    // stage 2/4 use easier pools, stage 5 can use harder pools
    if(stageId === 5){
      if(level <= 2) return 'katakana';
      if(level <= 4) return 'kanji';
      return 'kanji';
    }
    if(level <= 2) return 'alphabet';
    if(level === 3) return 'hiragana';
    if(level === 4) return 'katakana';
    return 'kanji';
  }

  function getParams(stageId, level){
    // Core knobs
    const flashMs = [700,550,450,350,250][level-1];
    const gapMs = Math.max(0, Math.round(flashMs * 0.15));
    let digits = 1;
    if(level === 2) digits = 2;
    if(level >= 3) digits = Math.min(3, level); // 3 at Lv3+

    let numCount = 5 + (level-1); // 5..9
    let trapCount = 0;

    const stage = STAGES.find(s=>s.id===stageId);
    const ops = stage.ops.slice();

    // Stage adjustments
    if(stageId === 1 || stageId === 2){
      // add-only
      trapCount = stage.trap ? Math.min(3, Math.max(0, level-2)) : 0; // Lv1-2:0, Lv3:1, Lv4:2, Lv5:3
    }else if(stageId === 3 || stageId === 4){
      // +/-
      numCount = 6 + (level-1); // 6..10
      trapCount = stage.trap ? Math.min(3, Math.max(0, level-2)) : 0;
    }else if(stageId === 5){
      // four ops, strict limits
      digits = Math.min(3, digits);
      numCount = Math.min(5, 3 + (level-1)); // 3..5, but capped at 5
      trapCount = Math.min(3, Math.max(0, level-2)); // 0..3
    }

    return {
      flashMs,
      gapMs,
      digits,
      numCount,
      trapCount,
      ops
    };
  }

  function makeNumber(digits){
    const min = digits <= 1 ? 0 : Math.pow(10, digits-1);
    const max = Math.pow(10, digits)-1;
    return randInt(min, max);
  }

  function makeAddOnlyTokens(digits, count){
    // numbers only (no + prefix)
    const arr = [];
    for(let i=0;i<count;i++){
      let v;
      for(let k=0;k<20;k++){
        v = makeNumber(digits);
        const disp = String(v);
        const prev = arr.length ? arr[arr.length-1].display : '';
        if(disp !== prev) break;
      }
      arr.push({type:'number', value:v, display:String(v)});
    }
    return arr;
  }

  function makePlusMinusTokens(digits, count){
    const arr = [];
    for(let i=0;i<count;i++){
      let sign = (i===0) ? '+' : (Math.random() < 0.5 ? '+' : '-'); // allow sign from start for consistency
      let v;
      for(let k=0;k<20;k++){
        v = makeNumber(digits);
        const disp = (sign === '+') ? ('+' + v) : ('-' + v);
        const prev = arr.length ? arr[arr.length-1].display : '';
        if(disp !== prev) break;
      }
      arr.push({type:'opnum', op:sign, value:v, display:(sign==='+'?('+'+v):('-'+v))});
    }
    return arr;
  }

  function makeFourOpsTokens(digits, count){
    // Format: first number then (op+number) tokens
    // count here is "numbers count" (max 5)
    const arr = [];
    // first number
    let first;
    for(let k=0;k<20;k++){
      first = makeNumber(digits);
      const disp = String(first);
      if(disp !== (arr.length?arr[arr.length-1].display:'')) break;
    }
    arr.push({type:'number', value:first, display:String(first)});

    const ops = ['+','-','×','÷'];
    for(let i=1;i<count;i++){
      const op = ops[randInt(0, ops.length-1)];
      let v;
      for(let k=0;k<40;k++){
        // keep operand small-ish for ×/÷
        if(op === '×') v = randInt(2, Math.min(99, Math.pow(10,digits)-1));
        else if(op === '÷') v = randInt(2, 9);
        else v = makeNumber(digits);

        const disp = op + String(v);
        const prev = arr.length ? arr[arr.length-1].display : '';
        if(disp === prev) continue;

        // ensure ÷ will be divisible later by fixing during evaluation stage; generation here is provisional
        break;
      }
      arr.push({type:'op', op, value:v, display:op+String(v)});
    }
    return arr;
  }

  function computeAnswer(stageId, tokens){
    // stage 1/2: sum numbers (all tokens of type number)
    if(stageId === 1 || stageId === 2){
      return tokens.filter(t=>t.type==='number').reduce((a,t)=>a + t.value, 0);
    }
    // stage 3/4: sum signed opnum tokens
    if(stageId === 3 || stageId === 4){
      let s = 0;
      for(const t of tokens){
        if(t.type !== 'opnum') continue;
        s += (t.op === '-') ? -t.value : t.value;
      }
      return s;
    }
    // stage 5: sequential evaluation with integer ÷
    let s = 0;
    for(let i=0;i<tokens.length;i++){
      const t = tokens[i];
      if(i===0 && t.type==='number'){ s = t.value; continue; }
      if(t.type!=='op') continue;
      const op = t.op;
      const v = t.value;
      if(op === '+') s = s + v;
      else if(op === '-') s = s - v;
      else if(op === '×') s = s * v;
      else if(op === '÷') s = Math.trunc(s / v);
    }
    return s;
  }

  function enforceDivisible(tokens){
    // Adjust ÷ operands to ensure exact division and avoid 0÷ issues
    let s = 0;
    for(let i=0;i<tokens.length;i++){
      const t = tokens[i];
      if(i===0 && t.type==='number'){ s = t.value; continue; }
      if(t.type !== 'op') continue;
      if(t.op === '÷'){
        if(s === 0){
          // avoid division after 0 by turning into + small number
          t.op = '+';
          t.value = randInt(1, 9);
          t.display = '+' + String(t.value);
          s = s + t.value;
          continue;
        }
        // choose a divisor of |s| (>=2)
        const abs = Math.abs(s);
        const divs = [];
        for(let d=2; d<=9; d++){
          if(abs % d === 0) divs.push(d);
        }
        if(divs.length === 0){
          // fallback: replace ÷ with + to keep game moving
          t.op = '+';
          t.value = randInt(1, 9);
          t.display = '+' + String(t.value);
          s = s + t.value;
          continue;
        }
        const d = divs[randInt(0, divs.length-1)];
        t.value = d;
        t.display = '÷' + String(d);
        s = s / d;
      }else if(t.op === '×'){
        s = s * t.value;
      }else if(t.op === '+'){
        s = s + t.value;
      }else if(t.op === '-'){
        s = s - t.value;
      }
    }
  }

  function insertTraps(stageId, level, baseTokens, trapCount){
    if(trapCount <= 0) return baseTokens.slice();

    const poolName = pickTrapPool(stageId, level);
    const pool = TRAP_POOLS[poolName] || TRAP_POOLS.alphabet;

    // insert only between tokens (avoid first/last by default)
    const slots = [];
    for(let i=1;i<baseTokens.length;i++) slots.push(i);
    // shuffle slots
    for(let i=slots.length-1;i>0;i--){
      const j = randInt(0,i);
      [slots[i], slots[j]] = [slots[j], slots[i]];
    }
    const picks = slots.slice(0, Math.min(trapCount, slots.length)).sort((a,b)=>a-b);

    const out = [];
    let pickIdx = 0;
    for(let i=0;i<baseTokens.length;i++){
      // before pushing baseTokens[i], insert trap if position matches
      if(pickIdx < picks.length && picks[pickIdx] === i){
        let ch = pool[randInt(0, pool.length-1)];
        // avoid repeat with previous visible token
        for(let k=0;k<20;k++){
          const prev = out.length ? out[out.length-1].display : '';
          if(String(ch) !== prev) break;
          ch = pool[randInt(0, pool.length-1)];
        }
        out.push({type:'trap', value:ch, pool:poolName, display:String(ch)});
        pickIdx++;
      }
      // also avoid base token repeating with previous (which might be trap)
      const tok = {...baseTokens[i]};
      for(let k=0;k<20;k++){
        const prev = out.length ? out[out.length-1].display : '';
        if(tok.display !== prev) break;

        // reroll only for number-like tokens; traps handled above
        if(tok.type === 'number'){
          tok.value = makeNumber(level >= 3 ? 3 : 2);
          tok.display = String(tok.value);
        }else if(tok.type === 'opnum'){
          tok.value = makeNumber(level >= 3 ? 3 : 2);
          tok.display = (tok.op === '+') ? ('+' + tok.value) : ('-' + tok.value);
        }else if(tok.type === 'op'){
          // reroll operand only
          if(tok.op === '×') tok.value = randInt(2, 99);
          else if(tok.op === '÷') tok.value = randInt(2, 9);
          else tok.value = makeNumber(level >= 3 ? 3 : 2);
          tok.display = tok.op + String(tok.value);
        }else{
          break;
        }
      }
      out.push(tok);
    }
    return out;
  }

  function buildRoundTokens(stageId, level){
    const p = getParams(stageId, level);

    let base;
    if(stageId === 1 || stageId === 2){
      base = makeAddOnlyTokens(p.digits, p.numCount);
    }else if(stageId === 3 || stageId === 4){
      base = makePlusMinusTokens(p.digits, p.numCount);
    }else{
      base = makeFourOpsTokens(p.digits, p.numCount);
      enforceDivisible(base);
    }

    const full = insertTraps(stageId, level, base, p.trapCount);

    // final pass: prevent any consecutive identical display (numbers OR traps)
    for(let i=1;i<full.length;i++){
      if(full[i].display === full[i-1].display){
        // try to tweak current token
        for(let k=0;k<20;k++){
          const prev = full[i-1].display;
          const tok = full[i];
          if(tok.type === 'trap'){
            const pool = TRAP_POOLS[tok.pool] || TRAP_POOLS.alphabet;
            tok.value = pool[randInt(0, pool.length-1)];
            tok.display = String(tok.value);
          }else if(tok.type === 'number'){
            tok.value = makeNumber(p.digits);
            tok.display = String(tok.value);
          }else if(tok.type === 'opnum'){
            tok.value = makeNumber(p.digits);
            tok.display = (tok.op === '+') ? ('+' + tok.value) : ('-' + tok.value);
          }else if(tok.type === 'op'){
            if(tok.op === '×') tok.value = randInt(2, Math.min(99, Math.pow(10,p.digits)-1));
            else if(tok.op === '÷') tok.value = randInt(2, 9);
            else tok.value = makeNumber(p.digits);
            tok.display = tok.op + String(tok.value);
          }
          if(full[i].display !== prev) break;
        }
      }
    }

    const answer = computeAnswer(stageId, base); // compute on base tokens only (traps ignored)
    return { tokens: full, answer, params: p };
  }

  async function countdown321(params){
    // 3 seconds countdown (3,2,1) in 1-second steps; no card design.
    showToken('3', {card:false}); await sleep(1000);
    showToken('2', {card:false}); await sleep(1000);
    showToken('1', {card:false}); await sleep(1000);
    showToken('', {card:false});
    await sleep(120);
  }

  function showToken(text, opts){
    const t = String(text ?? '');
    const card = opts && opts.card;
    flashToken.textContent = t;
    if(t){
      flashToken.classList.add('is-visible');
      if(card) flashToken.classList.add('is-card');
      else flashToken.classList.remove('is-card');
    }else{
      flashToken.classList.remove('is-visible');
      flashToken.classList.remove('is-card');
    }
  }

  async function flashTokens(tokens, params, stageId){
    for(const tok of tokens){
      // add-only stages: do not show '+' prefix anywhere
      if((stageId === 1 || stageId === 2) && tok.type === 'opnum'){
        showToken(String(tok.value), {card:true});
      }else{
        showToken(tok.display, {card:true});
      }
      await sleep(params.flashMs);
      showToken('', {card:true});
      if(params.gapMs) await sleep(params.gapMs);
    }
  }

  function resetInput(){
    state.input = '';
    renderInput();
  }

  function renderInput(){
    answerDisplay.textContent = state.input.length ? state.input : '0';
  }

  function appendDigit(d){
    if(state.input === '0') state.input = '';
    // keep reasonable length
    if(state.input.length >= 9) return;
    state.input += String(d);
    renderInput();
  }

  function backspace(){
    if(!state.input.length) return;
    state.input = state.input.slice(0, -1);
    renderInput();
  }

  function clearAll(){
    state.input = '';
    renderInput();
  }

  async function submitAnswer(){
    const given = state.input.length ? parseInt(state.input, 10) : 0;
    const correct = (given === state.sumAnswer);
    if(correct) state.correct += 1;

    // short feedback
    showToken(correct ? 'OK' : 'NG', {card:false});
    hide(keypadCard);
    await sleep(550);
    showToken('', {card:false});

    // next
    state.round += 1;
    if(state.round > state.totalRounds){
      finishGame();
      return;
    }
    await startRound();
  }

  function finishGame(){
    const score = state.correct;
    const meta = {
      game: 'flash_mental_math',
      stage: config.stage,
      level: config.level,
      rounds: state.totalRounds,
      correct: state.correct
    };
    if(window.platform_sdk && typeof window.platform_sdk.finish === 'function'){
      window.platform_sdk.finish(score, meta);
    }else{
      alert('Finished! score=' + score);
    }
  }

  async function startRound(){
    const stageId = config.stage;
    const level = config.level;

    hudRound.textContent = `Round ${state.round} / ${state.totalRounds}`;
    hudStage.textContent = `Stage ${stageId} / Lv${level}`;

    // build
    const built = buildRoundTokens(stageId, level);
    state.tokens = built.tokens;
    state.sumAnswer = built.answer;

    // countdown then flash
    hide(keypadCard);
    await countdown321(built.params);
    await flashTokens(state.tokens, built.params, stageId);

    // answer input
    resetInput();
    show(keypadCard);
  }

  // Keypad handlers
  function onKeyButton(e){
    const btn = e.target.closest('[data-key]');
    if(!btn) return;
    const k = btn.getAttribute('data-key');
    if(k === 'bksp') backspace();
    else if(k === 'clear') clearAll();
    else if(k === 'ok') submitAnswer();
    else if(/^[0-9]$/.test(k)) appendDigit(k);
  }

  function onKeydown(e){
    if(screenGame.classList.contains('is-hidden')) return;
    if(keypadCard.classList.contains('is-hidden')) return; // ignore during flash/countdown
    if(e.key >= '0' && e.key <= '9'){ appendDigit(e.key); return; }
    if(e.key === 'Backspace'){ e.preventDefault(); backspace(); return; }
    if(e.key === 'Enter'){ e.preventDefault(); submitAnswer(); return; }
    if(e.key === 'Escape'){ e.preventDefault(); clearAll(); return; }
  }

  // Init UI
  function initTop(){
    // stage
    for(const s of STAGES){
      const opt = document.createElement('option');
      opt.value = String(s.id);
      opt.textContent = s.name;
      stageSelect.appendChild(opt);
    }
    // level
    for(const lv of LEVELS){
      const opt = document.createElement('option');
      opt.value = String(lv);
      opt.textContent = 'Lv' + lv;
      levelSelect.appendChild(opt);
    }
    // rounds 1..10
    for(let r=1;r<=10;r++){
      const opt = document.createElement('option');
      opt.value = String(r);
      opt.textContent = String(r);
      roundSelect.appendChild(opt);
    }

    stageSelect.value = '1';
    levelSelect.value = '1';
    roundSelect.value = '10';
  }

  btnStart.addEventListener('click', async ()=>{
    config.stage = parseInt(stageSelect.value, 10);
    config.level = parseInt(levelSelect.value, 10);
    config.rounds = parseInt(roundSelect.value, 10);

    state.round = 1;
    state.totalRounds = config.rounds;
    state.correct = 0;

    setScreen('game');
    await startRound();
  });

  btnBackTop.addEventListener('click', ()=>{
    // Let outer shell handle back; fallback history
    if(window.parent && window.parent !== window){
      window.parent.postMessage({type:'GAME_BACK', game:'flash_mental_math'}, '*');
    }else{
      history.back();
    }
  });
  btnBackGame.addEventListener('click', ()=>{
    if(confirm('ゲームを中断して戻りますか？')){
      if(window.parent && window.parent !== window){
        window.parent.postMessage({type:'GAME_BACK', game:'flash_mental_math'}, '*');
      }else{
        history.back();
      }
    }
  });

  keypadCard.addEventListener('click', onKeyButton);
  document.addEventListener('keydown', onKeydown);

  initTop();
  setScreen('top');
})();
