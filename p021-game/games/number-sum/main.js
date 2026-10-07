/* Number Sums
   - 3-state (1=adopt, 0=unknown, -1=exclude)
   - Targets for rows/cols/regions
   - Infinite generation with: no 0/1 targets, unique solution, solvable by logic (no guessing)
   - UI: white background, region coloring, thick region borders, region badge shows current/target
*/
(function(){
  'use strict';

  // ---------- Utilities ----------
  const $ = (id)=>document.getElementById(id);
  const randInt = (a,b)=> (a + Math.floor(Math.random()*(b-a+1)));
  const shuffle = (arr)=>{
    for(let i=arr.length-1;i>0;i--){
      const j=Math.floor(Math.random()*(i+1));
      [arr[i],arr[j]]=[arr[j],arr[i]];
    }
    return arr;
  };
  const sleep = (ms)=>new Promise(r=>setTimeout(r,ms));

  // ---------- UI Elements ----------
  const modePencilBtn = $('modePencil');
  const modeEraserBtn = $('modeEraser');
  const btnNew = $('btnNew');
  const btnReset = $('btnReset');
  const btnLogic1 = $('btnLogic1');
  const btnSolve = $('btnSolve');
  const selLevel = $('selLevel'); // may be null (moved to TOP screen)
  const topLevel = $('topLevel');
  const btnStart = $('btnStart');
  const btnToTop = $('btnToTop');
  const screenTop = $('screenTop');
  const screenGame = $('screenGame');
  const boardWrap = $('boardWrap');
  const mainArea = document.querySelector('.main');
  const statusEl = $('status');
  const metaEl = $('meta');

  // In embed mode (/play iframe), header nodes may not exist.
  // Guard all writes so the game does not crash.
  const setStatus = (txt)=>{ if(statusEl) statusEl.textContent = String(txt ?? ''); };
  const setMeta   = (txt)=>{ if(metaEl)   metaEl.textContent   = String(txt ?? ''); };


  const overlay = $('overlay');
  const ovDetail = $('ovDetail');
  const btnCancel = $('btnCancel');

  // ---------- Game State ----------
  let mode = 'pencil'; // pencil|eraser
  let puzzle = null;   // current puzzle data
  let state = null;    // Int8Array per cell: -1,0,1
  let finished = false; // prevent double-finish
  let playStartedAt = 0;  // performance.now() when puzzle becomes playable
  // current selected level (TOP screen)
  let currentLevelKey = 'normal';
  let cellEls = [];    // DOM references
  let headerRowEls = []; // for rows
  let headerColEls = []; // for cols
  let regionBadgeCells = new Map(); // regionId => cellIndex (badge anchor)
  let gridEl = null;
  let isGenerating = false;
  let cancelGen = false;

  // Palette for regions (pastel)
  const palette = [
    '#fff7ed','#ecfeff','#f0fdf4','#fefce8','#f5f3ff','#eff6ff',
    '#fdf2f8','#fafafa','#f0f9ff','#fffbeb','#f7fee7','#eef2ff'
  ];

  // ---------- Core: Puzzle generation ----------
  function levelParams(levelKey){
    // Difficulty presets
    // easy   : 5x5
    // normal : 6x6
    // hard   : 7x7
    if(levelKey==='easy'){
      return {
        levelKey:'easy', N:5, max:7,
        regionMin:3, regionMax:5,
        densityMin:0.40, densityMax:0.70,
        logicMin:20, logicMax:500,
        uniqNodeLimit:180000
      };
    }
    if(levelKey==='hard'){
      return {
        levelKey:'hard', N:7,
        // 7x7 is close to a practical "generation cliff" when we require
        // (1) unique solution and (2) logic-only solvability.
        // To keep Hard 7x7 reliable, we bias towards stronger constraints
        // (slightly higher density, slightly smaller regions, and a narrower
        // value range) and allow a bit more solver budget.
        max:8,
        regionMin:4, regionMax:7,
        densityMin:0.40, densityMax:0.72,
        logicMin:90, logicMax:4500,
        uniqNodeLimit:1400000
      };
    }
    return {
      levelKey:'normal', N:6, max:8,
      regionMin:4, regionMax:6,
      densityMin:0.30, densityMax:0.54,
      logicMin:60, logicMax:1200,
      uniqNodeLimit:350000
    };
  }

  function idx(N,r,c){ return r*N+c; }

  function genRegions(N, rMin, rMax){
    // Build random polyomino regions via repeated growth.
    const regionIds = Array.from({length:N},()=>Array(N).fill(-1));
    const dirs = [[1,0],[-1,0],[0,1],[0,-1]];
    let rid = 0;

    const allCells = [];
    for(let r=0;r<N;r++) for(let c=0;c<N;c++) allCells.push([r,c]);
    shuffle(allCells);

    function neighbors(r,c){
      const out=[];
      for(const [dr,dc] of dirs){
        const nr=r+dr,nc=c+dc;
        if(nr>=0&&nr<N&&nc>=0&&nc<N) out.push([nr,nc]);
      }
      return out;
    }

    for(const [sr,sc] of allCells){
      if(regionIds[sr][sc]!==-1) continue;
      const targetSize = randInt(rMin, rMax);
      const cells = [[sr,sc]];
      regionIds[sr][sc]=rid;
      let frontier = neighbors(sr,sc).filter(([r,c])=>regionIds[r][c]===-1);

      while(cells.length < targetSize && frontier.length){
        // bias towards compact shapes: pick random from frontier
        const pick = frontier.splice(Math.floor(Math.random()*frontier.length),1)[0];
        const [r,c]=pick;
        if(regionIds[r][c]!==-1) continue;
        regionIds[r][c]=rid;
        cells.push([r,c]);
        for(const nb of neighbors(r,c)){
          const [nr,nc]=nb;
          if(regionIds[nr][nc]===-1) frontier.push(nb);
        }
      }
      rid++;
    }

    // Build region list
    const regions = Array.from({length:rid},()=>[]);
    for(let r=0;r<N;r++) for(let c=0;c<N;c++){
      const k=regionIds[r][c];
      regions[k].push([r,c]);
    }

    return {regionIds, regions, regionCount: rid};
  }

  function computeTargets(N, numbers, regionIds, regionCount, mask01){
    const rowTargets = Array(N).fill(0);
    const colTargets = Array(N).fill(0);
    const regionTargets = Array(regionCount).fill(0);

    for(let r=0;r<N;r++){
      for(let c=0;c<N;c++){
        if(mask01[idx(N,r,c)]===1){
          const v = numbers[r][c];
          rowTargets[r]+=v;
          colTargets[c]+=v;
          regionTargets[regionIds[r][c]]+=v;
        }
      }
    }
    return {rowTargets, colTargets, regionTargets};
  }

  function hasBadTargets(rowTargets,colTargets,regionTargets){
    for(const x of rowTargets) if(x===0||x===1) return true;
    for(const x of colTargets) if(x===0||x===1) return true;
    for(const x of regionTargets) if(x===0||x===1) return true;
    return false;
  }

  // ---------- Uniqueness solver (backtracking with pruning) ----------
  // This can be CPU-heavy. Keep it async and yield periodically so the UI
  // remains responsive (and Cancel works) during generation.
  async function uniqueSolutionCheck(puz, nodeLimit){
    const {N, numbers, regionIds, regionCount, rowTargets, colTargets, regionTargets} = puz;
    const total = N*N;
    // Order variables by value descending to speed pruning
    const order = [];
    for(let r=0;r<N;r++) for(let c=0;c<N;c++){
      order.push({i:idx(N,r,c), v:numbers[r][c], r, c, k:regionIds[r][c]});
    }
    order.sort((a,b)=>b.v-a.v);

    const rowCur = Array(N).fill(0), colCur = Array(N).fill(0), regCur = Array(regionCount).fill(0);
    const rowRem = Array(N).fill(0), colRem = Array(N).fill(0), regRem = Array(regionCount).fill(0);

    // initial remaining = sum of all in group
    for(let r=0;r<N;r++) for(let c=0;c<N;c++){
      const v=numbers[r][c], k=regionIds[r][c];
      rowRem[r]+=v; colRem[c]+=v; regRem[k]+=v;
    }

    const assign = new Int8Array(total).fill(-1); // -1 unassigned; 0 exclude; 1 include
    let nodes=0, sols=0;

    function feasibleGroup(cur, rem, target){
      if(cur>target) return false;
      if(cur+rem<target) return false;
      return true;
    }

    let lastYield = performance.now();

    async function maybeYield(){
      // Yield about once per frame (or when cancellation requested)
      if(cancelGen) return;
      if(nodes % 4096 !== 0) return;
      const now = performance.now();
      if(now - lastYield < 12) return;
      lastYield = now;
      await sleep(0);
    }

    async function dfs(pos){
      if(cancelGen) return;
      if(sols>1) return;
      nodes++;
      if(nodes>nodeLimit) return;

      await maybeYield();

      if(pos>=order.length){
        // must hit all targets exactly
        for(let r=0;r<N;r++) if(rowCur[r]!==rowTargets[r]) return;
        for(let c=0;c<N;c++) if(colCur[c]!==colTargets[c]) return;
        for(let k=0;k<regionCount;k++) if(regCur[k]!==regionTargets[k]) return;
        sols++;
        return;
      }

      const {i,v,r,c,k}=order[pos];
      // remove from remaining (this var will be decided)
      rowRem[r]-=v; colRem[c]-=v; regRem[k]-=v;

      // Try include first (often prunes faster on big numbers)
      for(const take of [1,0]){
        if(cancelGen) break;
        assign[i]=take;
        if(take===1){
          rowCur[r]+=v; colCur[c]+=v; regCur[k]+=v;
        }
        const ok =
          feasibleGroup(rowCur[r], rowRem[r], rowTargets[r]) &&
          feasibleGroup(colCur[c], colRem[c], colTargets[c]) &&
          feasibleGroup(regCur[k], regRem[k], regionTargets[k]);

        if(ok){
          await dfs(pos+1);
        }

        if(take===1){
          rowCur[r]-=v; colCur[c]-=v; regCur[k]-=v;
        }
        if(sols>1) break;
      }

      assign[i]=-1;
      // restore remaining
      rowRem[r]+=v; colRem[c]+=v; regRem[k]+=v;
    }

    await dfs(0);
    return {unique: sols===1 && nodes<=nodeLimit, sols, nodes};
  }

  // ---------- Logic solver (no guessing) ----------
  function logicSolve(puz, maxIters){
    const {N, numbers, regionIds, regionCount, rowTargets, colTargets, regionTargets} = puz;
    const total=N*N;
    const st = new Int8Array(total).fill(0); // start unknown
    let steps=0;

    function groupCellsRow(r){
      const out=[];
      for(let c=0;c<N;c++) out.push(idx(N,r,c));
      return out;
    }
    function groupCellsCol(c){
      const out=[];
      for(let r=0;r<N;r++) out.push(idx(N,r,c));
      return out;
    }
    const regionCells = Array.from({length:regionCount},()=>[]);
    for(let r=0;r<N;r++) for(let c=0;c<N;c++){
      regionCells[regionIds[r][c]].push(idx(N,r,c));
    }

    function sumCurRem(cells){
      let cur=0, rem=0;
      for(const i of cells){
        const v = numbers[Math.floor(i/N)][i%N];
        if(st[i]===1) cur+=v;
        else if(st[i]===0) rem+=v;
      }
      return {cur, rem};
    }

    function reachable(cur, rem, target){
      if(cur>target) return false;
      if(cur+rem<target) return false;
      return true;
    }

    function applyGroupRule(cells, target){
      const {cur, rem} = sumCurRem(cells);
      if(cur===target){
        // all unknown => exclude
        let changed=false;
        for(const i of cells){
          if(st[i]===0){ st[i]=-1; changed=true; }
        }
        return changed;
      }
      if(cur+rem===target){
        let changed=false;
        for(const i of cells){
          if(st[i]===0){ st[i]=1; changed=true; }
        }
        return changed;
      }
      return false;
    }

    function contradictionAt(i, assumed){
      // check row/col/region reachability only (cheap)
      const r = Math.floor(i/N), c=i%N, k=regionIds[r][c];
      const v = numbers[r][c];

      function testCells(cells, target){
        let cur=0, rem=0;
        for(const j of cells){
          const rr=Math.floor(j/N), cc=j%N;
          const vv=numbers[rr][cc];
          let s = st[j];
          if(j===i) s = assumed;
          if(s===1) cur+=vv;
          else if(s===0) rem+=vv;
        }
        return reachable(cur, rem, target);
      }

      const rowCells = groupCellsRow(r);
      const colCells = groupCellsCol(c);
      const regCells = regionCells[k];

      if(!testCells(rowCells, rowTargets[r])) return true;
      if(!testCells(colCells, colTargets[c])) return true;
      if(!testCells(regCells, regionTargets[k])) return true;
      return false;
    }

    let changed=true;
    let iters=0;
    while(changed && iters<maxIters){
      iters++;
      changed=false;

      // basic group saturation rules
      for(let r=0;r<N;r++) if(applyGroupRule(groupCellsRow(r), rowTargets[r])){ changed=true; steps++; }
      for(let c=0;c<N;c++) if(applyGroupRule(groupCellsCol(c), colTargets[c])){ changed=true; steps++; }
      for(let k=0;k<regionCount;k++) if(applyGroupRule(regionCells[k], regionTargets[k])){ changed=true; steps++; }

      // implication for single cell
      for(let i=0;i<total;i++){
        if(st[i]!==0) continue;
        const contraIfOn = contradictionAt(i, 1);
        const contraIfOff = contradictionAt(i, -1);
        if(contraIfOn && !contraIfOff){ st[i]=-1; changed=true; steps++; }
        else if(contraIfOff && !contraIfOn){ st[i]=1; changed=true; steps++; }
      }
    }

    let solved=true;
    for(let i=0;i<total;i++){ if(st[i]===0){ solved=false; break; } }
    // verify
    if(solved){
      // compute sums
      const rowCur = Array(N).fill(0), colCur = Array(N).fill(0), regCur = Array(regionCount).fill(0);
      for(let r=0;r<N;r++) for(let c=0;c<N;c++){
        const i=idx(N,r,c);
        if(st[i]===1){
          const v=numbers[r][c], k=regionIds[r][c];
          rowCur[r]+=v; colCur[c]+=v; regCur[k]+=v;
        }
      }
      for(let r=0;r<N;r++) if(rowCur[r]!==rowTargets[r]) solved=false;
      for(let c=0;c<N;c++) if(colCur[c]!==colTargets[c]) solved=false;
      for(let k=0;k<regionCount;k++) if(regCur[k]!==regionTargets[k]) solved=false;
    }

    return {solved, steps, state: st};
  }

  async function generatePuzzle(levelKey){
    const base = levelParams(levelKey);

    // 7x7 (Hard) needs more sampling to consistently find a board that is
    // both uniquely solvable and logic-only solvable.
    const isHard = (base.levelKey === 'hard');
    const stages = [
      {
        name:'strict',
        tries: isHard ? 140 : 80,
        nodeLimit: base.uniqNodeLimit,
        logicMin: base.logicMin,
        logicMax: base.logicMax
      },
      {
        name:'mid',
        tries: isHard ? 240 : 120,
        nodeLimit: Math.floor(base.uniqNodeLimit*1.35),
        logicMin: Math.floor(base.logicMin*0.7),
        logicMax: Math.floor(base.logicMax*1.2)
      },
      {
        name:'relaxed',
        tries: isHard ? 340 : 160,
        nodeLimit: Math.floor(base.uniqNodeLimit*1.75),
        logicMin: Math.floor(base.logicMin*0.5),
        logicMax: Math.floor(base.logicMax*1.4)
      },
    ];

    let totalTries = 0;
    for(const stage of stages){
      for(let t=0;t<stage.tries;t++){
        if(cancelGen) return null;
        totalTries++;

        if(totalTries%8===0) await sleep(0); // yield to UI

        // 1) regions
        const {regionIds, regions, regionCount} = genRegions(base.N, base.regionMin, base.regionMax);

        // 2) numbers
        const numbers = Array.from({length:base.N},()=>Array.from({length:base.N},()=>randInt(1, base.max)));

        // 3) mask
        const density = base.densityMin + Math.random()*(base.densityMax-base.densityMin);
        const mask01 = new Int8Array(base.N*base.N);
        for(let i=0;i<mask01.length;i++) mask01[i] = (Math.random()<density)?1:0;

        // 4) targets
        const {rowTargets, colTargets, regionTargets} = computeTargets(base.N, numbers, regionIds, regionCount, mask01);
        if(hasBadTargets(rowTargets,colTargets,regionTargets)) continue;

        const puz = {
          levelKey: base.levelKey,
          N: base.N,
          numbers,
          regionIds,
          regions,
          regionCount,
          rowTargets,
          colTargets,
          regionTargets,
          meta: {tries: totalTries, relaxStage: stage.name}
        };

        // 5) uniqueness
        const uq = await uniqueSolutionCheck(puz, stage.nodeLimit);
        if(!uq.unique) continue;

        // 6) logic solvable (no guessing)
        const lg = logicSolve(puz, 5000);
        if(!lg.solved) continue;
        if(lg.steps < stage.logicMin || lg.steps > stage.logicMax) continue;

        puz.meta.uniqNodes = uq.nodes;
        puz.meta.logicSteps = lg.steps;
        puz.solution = lg.state; // optional: solved state from logic (since solvable)
        return puz;
      }
    }
    return null;
  }

  // ---------- Rendering ----------
  function setMode(next){
    mode=next;
    modePencilBtn.classList.toggle('is-active', mode==='pencil');
    modeEraserBtn.classList.toggle('is-active', mode==='eraser');
  }

  function showOverlay(on, detail){
    overlay.classList.toggle('hidden', !on);
    if(detail) ovDetail.textContent = detail;
  }

  function buildRegionBadges(){
    regionBadgeCells.clear();
    const N=puzzle.N;
    // pick top-left-most cell in each region
    for(let k=0;k<puzzle.regionCount;k++){
      let best=null;
      for(const [r,c] of puzzle.regions[k]){
        if(!best) best=[r,c];
        else if(r<best[0] || (r===best[0] && c<best[1])) best=[r,c];
      }
      regionBadgeCells.set(k, idx(N,best[0],best[1]));
    }
  }

  function computeSumsFromState(){
    const N=puzzle.N;
    const rowCur = Array(N).fill(0);
    const colCur = Array(N).fill(0);
    const regCur = Array(puzzle.regionCount).fill(0);

    for(let r=0;r<N;r++) for(let c=0;c<N;c++){
      const i=idx(N,r,c);
      if(state[i]===1){
        const v=puzzle.numbers[r][c];
        rowCur[r]+=v;
        colCur[c]+=v;
        regCur[puzzle.regionIds[r][c]]+=v;
      }
    }
    return {rowCur,colCur,regCur};
  }

  function updateHeadersAndBadges(){
    if(!puzzle) return;
    const N=puzzle.N;
    const {rowCur,colCur,regCur} = computeSumsFromState();

    for(let r=0;r<N;r++){
      const el = headerRowEls[r];
      if(!el) continue;
      const cur=rowCur[r], tgt=puzzle.rowTargets[r];
      el.querySelector('.t').textContent = String(tgt);
      el.querySelector('.c').textContent = String(cur);
      el.classList.toggle('ok', cur===tgt);
      el.classList.toggle('over', cur>tgt);
    }
    for(let c=0;c<N;c++){
      const el = headerColEls[c];
      if(!el) continue;
      const cur=colCur[c], tgt=puzzle.colTargets[c];
      el.querySelector('.t').textContent = String(tgt);
      el.querySelector('.c').textContent = String(cur);
      el.classList.toggle('ok', cur===tgt);
      el.classList.toggle('over', cur>tgt);
    }

    // region badges
    for(const [k, anchorIdx] of regionBadgeCells.entries()){
      const badge = cellEls[anchorIdx]?.querySelector('.regionBadge');
      if(!badge) continue;
      badge.textContent = `${regCur[k]}/${puzzle.regionTargets[k]}`;
      // feedback
      const ok = regCur[k]===puzzle.regionTargets[k];
      const over = regCur[k]>puzzle.regionTargets[k];
      badge.style.borderColor = over ? 'rgba(220,38,38,.55)' : (ok ? 'rgba(22,163,74,.55)' : 'rgba(17,24,39,.25)');
      badge.style.color = over ? '#b91c1c' : (ok ? '#166534' : 'var(--fg)');
    }

    // win check
    let allFixed=true;
    for(let i=0;i<N*N;i++){ if(state[i]===0){ allFixed=false; break; } }
    let win=false;
    if(allFixed){
      win=true;
      for(let r=0;r<N;r++) if(rowCur[r]!==puzzle.rowTargets[r]) win=false;
      for(let c=0;c<N;c++) if(colCur[c]!==puzzle.colTargets[c]) win=false;
      for(let k=0;k<puzzle.regionCount;k++) if(regCur[k]!==puzzle.regionTargets[k]) win=false;
    }
    setStatus(win ? 'クリア！ 全て一致しています。' : 'プレイ中');
    if(win && !finished){
      finished = true;

      const now = performance.now();
      const elapsedSec = (playStartedAt>0) ? Math.max(0, Math.floor((now - playStartedAt)/1000)) : null;
      // Score must be a finite number. Use higher-is-better with a soft cap.
      const score = (elapsedSec===null) ? 1 : Math.max(0, 9999 - elapsedSec);
      const meta = {
        level: puzzle.levelKey,
        elapsed_sec: elapsedSec,
        logicSteps: (puzzle.meta && typeof puzzle.meta==='object') ? (puzzle.meta.logicSteps ?? null) : null
      };

      // NOTE: In iframe sandbox mode, alert() requires allow-modals.
      // Show the result first, then submit score on OK.
      try{ alert('正解！'); }catch(_){ }
      try{ platform_sdk.finish(score, meta); }catch(_){ }
    }
  }

  function setCellBorders(el, r, c){
    const N=puzzle.N;
    const k = puzzle.regionIds[r][c];
    const thick = 4; // region boundary thickness (slightly thicker)
    const thin = 1;

    const topK = (r>0)?puzzle.regionIds[r-1][c]:null;
    const leftK = (c>0)?puzzle.regionIds[r][c-1]:null;

    // default thin, then bump boundaries
    let bt=thin, bl=thin;
    if(r===0) bt=thick;
    else if(topK!==k) bt=thick;

    if(c===0) bl=thick;
    else if(leftK!==k) bl=thick;

    // right/bottom handled by neighbor's left/top; but keep outer thick
    let br=thin, bb=thin;
    if(c===N-1) br=thick;
    if(r===N-1) bb=thick;

    el.style.borderTop = `${bt}px solid var(--line)`;
    el.style.borderLeft = `${bl}px solid var(--line)`;
    el.style.borderRight = `${br}px solid var(--line)`;
    el.style.borderBottom = `${bb}px solid var(--line)`;
  }

  function renderPuzzle(){
    boardWrap.innerHTML='';
    cellEls=[];
    headerRowEls=[];
    headerColEls=[];
    const N = puzzle.N;

    // Make the board fill the available width.
    // Compute a cell size based on container width, with a reasonable clamp.
    const wrapW = (boardWrap && boardWrap.clientWidth) ? boardWrap.clientWidth : 0;
    // The first row/col are narrower. Use weighted sizing so the board fits.
    const headRatio = 0.72;
    const weightedCols = (1 * headRatio) + N;
    let cell = Math.floor((wrapW - 2) / Math.max(1, weightedCols));
    if(!Number.isFinite(cell) || cell<=0) cell = 38;
    cell = Math.max(28, Math.min(52, cell));

    // Header row/col are slightly narrower than number cells.
    // - left column: narrower width
    // - top row: narrower height
    // Keep number cells uniform.
    const headW = Math.max(22, Math.min(cell - 6, Math.floor(cell * headRatio)));
    const headH = Math.max(22, Math.min(cell - 6, Math.floor(cell * headRatio)));

    // Grid: (N+1)x(N+1). [0,0] empty. top row headers: cols. left col headers: rows. rest: cells.
    const grid = document.createElement('div');
    grid.className='grid';
    grid.style.setProperty('--cell', `${cell}px`);
    // first column/row are sum headers
    grid.style.gridTemplateColumns = `${headW}px repeat(${N}, ${cell}px)`;
    grid.style.gridTemplateRows = `${headH}px repeat(${N}, ${cell}px)`;
    gridEl = grid;

    // empty corner
    const corner = document.createElement('div');
    corner.className='hcell';
    corner.style.background='#fff';
    corner.innerHTML = '<div class="t"></div><div class="c"></div>';
    grid.appendChild(corner);

    // col headers
    for(let c=0;c<N;c++){
      const h=document.createElement('div');
      h.className='hcell';
      h.innerHTML = '<div class="t">0</div><div class="c">0</div>';
      headerColEls[c]=h;
      grid.appendChild(h);
    }

    // rows + cells
    for(let r=0;r<N;r++){
      const h=document.createElement('div');
      h.className='hcell';
      h.innerHTML = '<div class="t">0</div><div class="c">0</div>';
      headerRowEls[r]=h;
      grid.appendChild(h);

      for(let c=0;c<N;c++){
        const i=idx(N,r,c);
        const el=document.createElement('div');
        el.className='cell';
        el.setAttribute('role','button');
        el.setAttribute('tabindex','0');
        el.dataset.r=String(r);
        el.dataset.c=String(c);
        if(c===N-1) el.dataset.lastcol='1';
        if(r===N-1) el.dataset.lastrow='1';

        const k=puzzle.regionIds[r][c];
        const bg=palette[k % palette.length];
        el.style.background = bg;

        // thick borders at region boundaries
        setCellBorders(el, r, c);

        // number (wrap for per-layer styling)
        const num=document.createElement('span');
        num.className='num';
        num.textContent = String(puzzle.numbers[r][c]);
        el.appendChild(num);

        // mark overlay
        const mark=document.createElement('div');
        mark.className='mark';
        el.appendChild(mark);

        // region badge anchor cell only
        if(regionBadgeCells.get(k)===i){
          const badge=document.createElement('div');
          badge.className='regionBadge';
          badge.textContent='0/0';
          el.appendChild(badge);
        }

        el.addEventListener('click', ()=>onCell(i));
        el.addEventListener('keydown', (ev)=>{
          if(ev.key==='Enter' || ev.key===' '){
            ev.preventDefault();
            onCell(i);
          }
        });

        cellEls[i]=el;
        grid.appendChild(el);
      }
    }

    boardWrap.appendChild(grid);

    // Fit the board into the visible area (avoid being pushed out by controls)
    requestAnimationFrame(()=>fitBoard());

    // init view state
    for(let i=0;i<N*N;i++) applyCellClass(i);
    updateHeadersAndBadges();

    const m=puzzle.meta||{};
    setMeta(`tries:${m.tries ?? '-'}  uniqNodes:${m.uniqNodes ?? '-'}  logicSteps:${m.logicSteps ?? '-'}  stage:${m.relaxStage ?? '-'}`);
    setStatus('プレイ中');
  }

  function fitBoard(){
    // Fit the board to the visible area and keep the controls visible.
    // We prefer computing an appropriate cell size over CSS transform scaling,
    // so the board naturally becomes 100% width on small screens.
    if(!gridEl || !boardWrap || !puzzle) return;

    const N = puzzle.N;
    const totalCols = N + 1; // includes header row/col
    const totalRows = N + 1;

    const containerW = boardWrap.clientWidth || 0;
    if(containerW<=0) return;

    // Available height = main area height minus controls row height.
    const mainH = (mainArea && mainArea.clientHeight) ? mainArea.clientHeight : 0;
    const controlsEl = document.querySelector('.controlsRow');
    const controlsH = controlsEl ? (controlsEl.offsetHeight || 0) : 0;
    const availableH = Math.max(0, mainH - controlsH - 12);

    const pad = 8;
    // Because the first row/col are narrower, approximate sizing by a weighted total.
    // head size is ~0.72 of a regular cell.
    const headRatio = 0.72;
    const weightedCols = (1 * headRatio) + N;
    const weightedRows = (1 * headRatio) + N;

    const maxCellW = (containerW - pad) / weightedCols;
    const maxCellH = availableH>0 ? ((availableH - pad) / weightedRows) : maxCellW;

    let cell = Math.floor(Math.min(maxCellW, maxCellH));
    // reasonable clamp
    cell = Math.max(30, Math.min(60, cell));

    // Apply sizing
    const headW = Math.max(22, Math.min(cell - 6, Math.floor(cell * headRatio)));
    const headH = Math.max(22, Math.min(cell - 6, Math.floor(cell * headRatio)));

    gridEl.style.transform = 'none';
    gridEl.style.transformOrigin = '';
    gridEl.style.setProperty('--cell', `${cell}px`);
    gridEl.style.gridTemplateColumns = `${headW}px repeat(${N}, ${cell}px)`;
    gridEl.style.gridTemplateRows = `${headH}px repeat(${N}, ${cell}px)`;
    gridEl.style.width = `${Math.floor(headW + cell * N)}px`;
    boardWrap.style.minHeight = '';
  }

  function applyCellClass(i){
    const el=cellEls[i];
    if(!el) return;
    el.classList.toggle('is-on', state[i]===1);
    el.classList.toggle('is-off', state[i]===-1);
  }

  function onCell(i){
    if(!puzzle || isGenerating) return;
    const cur=state[i];
    let next=cur;
    if(mode==='pencil'){
      next = (cur===1)?0:1;
    }else{
      next = (cur===-1)?0:-1;
    }
    state[i]=next;
    applyCellClass(i);
    updateHeadersAndBadges();
  }

  // ---------- Actions ----------
  function resetState(){
    if(!puzzle) return;
    state = new Int8Array(puzzle.N*puzzle.N).fill(0);
    finished = false;
    playStartedAt = performance.now();
    for(let i=0;i<state.length;i++) applyCellClass(i);
    updateHeadersAndBadges();
  }

  function applyLogicOnce(){
    if(!puzzle) return;
    // run one iteration of rules (groups + implications once)
    const N=puzzle.N;
    const total=N*N;

    const regionCells = Array.from({length:puzzle.regionCount},()=>[]);
    for(let r=0;r<N;r++) for(let c=0;c<N;c++){
      regionCells[puzzle.regionIds[r][c]].push(idx(N,r,c));
    }

    const numbers=puzzle.numbers;

    function sumCurRem(cells){
      let cur=0, rem=0;
      for(const i of cells){
        const v=numbers[Math.floor(i/N)][i%N];
        if(state[i]===1) cur+=v;
        else if(state[i]===0) rem+=v;
      }
      return {cur, rem};
    }
    function applyGroupRule(cells, target){
      const {cur, rem}=sumCurRem(cells);
      if(cur===target){
        let ch=false;
        for(const i of cells) if(state[i]===0){ state[i]=-1; ch=true; applyCellClass(i); }
        return ch;
      }
      if(cur+rem===target){
        let ch=false;
        for(const i of cells) if(state[i]===0){ state[i]=1; ch=true; applyCellClass(i); }
        return ch;
      }
      return false;
    }
    function reachable(cur, rem, target){ return !(cur>target || cur+rem<target); }

    function contradictionAt(i, assumed){
      const r=Math.floor(i/N), c=i%N, k=puzzle.regionIds[r][c];
      function test(cells, target){
        let cur=0, rem=0;
        for(const j of cells){
          const rr=Math.floor(j/N), cc=j%N;
          const v=numbers[rr][cc];
          let s=state[j];
          if(j===i) s=assumed;
          if(s===1) cur+=v;
          else if(s===0) rem+=v;
        }
        return reachable(cur, rem, target);
      }
      const row=[]; for(let cc=0;cc<N;cc++) row.push(idx(N,r,cc));
      const col=[]; for(let rr=0;rr<N;rr++) col.push(idx(N,rr,c));
      if(!test(row, puzzle.rowTargets[r])) return true;
      if(!test(col, puzzle.colTargets[c])) return true;
      if(!test(regionCells[k], puzzle.regionTargets[k])) return true;
      return false;
    }

    let changed=false;

    // group rules once
    for(let r=0;r<N;r++){
      const cells=[]; for(let c=0;c<N;c++) cells.push(idx(N,r,c));
      if(applyGroupRule(cells, puzzle.rowTargets[r])) changed=true;
    }
    for(let c=0;c<N;c++){
      const cells=[]; for(let r=0;r<N;r++) cells.push(idx(N,r,c));
      if(applyGroupRule(cells, puzzle.colTargets[c])) changed=true;
    }
    for(let k=0;k<puzzle.regionCount;k++){
      if(applyGroupRule(regionCells[k], puzzle.regionTargets[k])) changed=true;
    }

    // implication once
    for(let i=0;i<total;i++){
      if(state[i]!==0) continue;
      const contraOn = contradictionAt(i, 1);
      const contraOff = contradictionAt(i, -1);
      if(contraOn && !contraOff){ state[i]=-1; applyCellClass(i); changed=true; }
      else if(contraOff && !contraOn){ state[i]=1; applyCellClass(i); changed=true; }
    }

    updateHeadersAndBadges();
    if(!changed) setStatus('ロジック1手：変化なし');
  }

  function solveByLogic(){
    if(!puzzle) return;
    const lg = logicSolve(puzzle, 5000);
    state = new Int8Array(lg.state); // copy
    for(let i=0;i<state.length;i++) applyCellClass(i);
    updateHeadersAndBadges();
    setStatus(lg.solved ? 'ロジックで解きました（推測なし）' : 'ロジックだけでは確定できません');
  }

  async function newPuzzle(levelKeyArg){
    if(isGenerating) return;
    cancelGen=false;
    isGenerating=true;
    setStatus('問題生成中…');
    showOverlay(true, '条件を満たす盤面（唯一解・ロジックのみ）を探索しています。');

    const levelKey = (levelKeyArg || currentLevelKey || 'normal');
    if(selLevel) selLevel.value = levelKey;
    if(topLevel) topLevel.value = levelKey;
    const start=performance.now();

    let puz=null;
    // Hard 7x7 may need several restarts depending on randomness.
    const maxRestarts = (levelKey==='hard') ? 6 : 3;
    for(let attempt=0; attempt<maxRestarts && !puz; attempt++){
      if(cancelGen) break;
      puz = await generatePuzzle(levelKey);
      if(!puz && !cancelGen){
        showOverlay(true, '別パターンでもう一度探索しています…');
        await sleep(0);
      }
    }

    if(cancelGen){
      showOverlay(false);
      setStatus('キャンセルしました');
      isGenerating=false;
      return;
    }

    if(!puz){
      // In embedded mode, status may not be visible. Keep the overlay open
      // so the user receives feedback.
      showOverlay(true, '生成に失敗しました。もう一度お試しください。（キャンセルで閉じる）');
      setStatus('生成に失敗しました');
      isGenerating=false;
      return;
    }

    puzzle=puz;
    buildRegionBadges();
    state = new Int8Array(puzzle.N*puzzle.N).fill(0);
    renderPuzzle();

    finished = false;
    playStartedAt = performance.now();

    const ms=Math.round(performance.now()-start);
    setStatus(`プレイ中（生成 ${ms}ms）`);
    showOverlay(false);
    isGenerating=false;
  }


  function showTop(){
    if(screenGame) screenGame.classList.add('hidden');
    if(screenTop) screenTop.classList.remove('hidden');
    setStatus('TOPで開始してください');
  }

  function showGame(){
    if(screenTop) screenTop.classList.add('hidden');
    if(screenGame) screenGame.classList.remove('hidden');
  }

  // ---------- Wiring ----------
  if(modePencilBtn) modePencilBtn.addEventListener('click', ()=>setMode('pencil'));
  if(modeEraserBtn) modeEraserBtn.addEventListener('click', ()=>setMode('eraser'));
  if(btnReset) btnReset.addEventListener('click', ()=>resetState());
  if(btnLogic1) btnLogic1.addEventListener('click', ()=>applyLogicOnce());
  if(btnSolve) btnSolve.addEventListener('click', ()=>solveByLogic());
  if(btnNew) btnNew.addEventListener('click', ()=>newPuzzle(currentLevelKey));
  if(btnStart){
    btnStart.addEventListener('click', ()=>{
      const lv = (topLevel && topLevel.value) ? topLevel.value : 'normal';
      currentLevelKey = lv;
      showGame();
      setMode('pencil');
      newPuzzle(lv);
    });
  }
  if(btnToTop){
    btnToTop.addEventListener('click', ()=>{
      cancelGen = true;
      showOverlay(false);
      // When embedded in /play/{game_id}, return-to-top must go through the platform ad gate.
      // Fallback to the in-game TOP screen when opened standalone.
      try{
        if(window !== window.parent && window.platform_sdk && typeof window.platform_sdk.back_to_top === 'function'){
          window.platform_sdk.back_to_top();
          return;
        }
      }catch(_){ /* ignore and fallback */ }
      showTop();
    });
  }
  if(topLevel){
    topLevel.addEventListener('change', ()=>{ currentLevelKey = topLevel.value || 'normal'; });
  }

  btnCancel.addEventListener('click', ()=>{
    if(isGenerating){
      cancelGen=true;
      ovDetail.textContent='キャンセル処理中…';
      return;
    }
    showOverlay(false);
  });

  // initial
  setMode('pencil');
  // start from TOP screen
  showTop();

  // keep board fitted when the viewport changes (e.g., after ad overlay / rotation)
  window.addEventListener('resize', ()=>fitBoard());
  if('ResizeObserver' in window){
    try{
      const ro = new ResizeObserver(()=>fitBoard());
      if(mainArea) ro.observe(mainArea);
      if(boardWrap) ro.observe(boardWrap);
    }catch(_){ /* ignore */ }
  }

})();
