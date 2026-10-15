// GAME-071: Real touch/mouse E2E; no QA commands or direct physics/state writes.
// qa=1 provides deterministic cargo and read-only snapshots, NOT success shortcuts.
const { chromium } = require('playwright');
const fs = require('fs');
const targets = [
  { name:'phone-portrait', width:390, height:844, input:'touch' },
  { name:'phone-landscape', width:844, height:390, input:'mouse' },
  { name:'tablet-portrait', width:768, height:1024, input:'touch' },
  { name:'tablet-landscape', width:1024, height:768, input:'mouse' },
];
// GAME-076: lightweight responsive intro + natural-start PLAYING geometry sweep.
// This is not an additional NIGHT/ACE E2E run and cannot certify human legibility.
const layoutTargets = [
  {name:'small-phone-portrait',width:320,height:568},
  {name:'small-phone-landscape',width:667,height:375},
  {name:'compact-tablet-landscape',width:800,height:600},
];
const dir = '/tmp/p021-g030-real-input';
const url = 'http://127.0.0.1:8000/p021-game/games/orbit-switch-courier/?qa=1';
function check(value, message) { if (!value) throw new Error(message); }
function fits(r,w,h) { return r && r.length===4 && r[0]>=-2 && r[1]>=-2 &&
  r[2]>100 && r[3]>70 && r[0]+r[2]<=w+2 && r[1]+r[3]<=h+2; }

// GAME-076 visual-quality contract: inspect the actual Godot source under QA.
// This checks authored colors and sizes only; no game state manipulation.
function colorLuminance(hex) {
  const [r,g,b] = hex.slice(1).match(/../g).map(x => parseInt(x,16)/255)
    .map(x => x<=0.04045 ? x/12.92 : Math.pow((x+0.055)/1.055,2.4));
  return r*0.2126+g*0.7152+b*0.0722;
}
function textContrast(fg,bg) {
  const a=colorLuminance(fg), b=colorLuminance(bg);
  return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);
}
function verifyGuideContrast() {
  const source=fs.readFileSync('p021-game/sources/orbit-switch-courier-godot/Main.gd','utf8');
  const cases=[
    {name:'phone-landscape two-step guide',from:'var help_band :=',
      to:'# Tablet landscape:',shape:'help_band'},
    {name:'tablet bottom guide',from:'var guide_band :=',
      to:'func _draw_intro_overlay()',shape:'guide_band'}
  ];
  const results=[];
  for(const c of cases) {
    const a=source.indexOf(c.from), b=source.indexOf(c.to,a);
    check(a>=0 && b>a,'Missing Godot guide section: '+c.name);
    const snippet=source.slice(a,b);
    const background=snippet.match(new RegExp('_rounded_box\\('+c.shape+', Color\\("(#[0-9a-fA-F]{6})"\\)'));
    check(background,'Missing guide background: '+c.name);
    const labels=[...snippet.matchAll(/_draw_fit_label\([^\n]*?_font_size\((\d+(?:\.\d+)?)\), Color\("(#[0-9a-fA-F]{6})"\)/g)];
    check(labels.length===2,'Expected exactly two guide label colors: '+c.name);
    for(const label of labels) {
      const fontPx=Number(label[1]), contrast=textContrast(label[2],background[1]);
      check(fontPx>=16,'Guide text smaller than 16 CSS pixels: '+c.name);
      check(contrast>=7,'Guide contrast below 7:1: '+c.name+' '+contrast.toFixed(2));
      results.push({area:c.name,fontCssPx:fontPx,foreground:label[2],
        background:background[1],wcagContrast:Number(contrast.toFixed(2)),
        status:'PASS_STATIC'});
    }
  }
  check(source.includes('var minimum_size := _font_size(12.0)') &&
    source.includes('while shown.length() > 1') &&
    source.includes('_draw_center_fit_text(_visible_cue(), cue_r'),
    'Cue min-size / ellipsis / banner render contract missing');
  // GAME-076: long structured cues must preserve three semantic priorities
  // across two rows. These source assertions do not substitute for screenshot review.
  check(source.includes('func _cue_priority_lines()') &&
    source.includes('route = phrase.substr(6).strip_edges()') &&
    source.includes('NEXT · TAP NOW表示で目標HUBへ') &&
    source.includes('_draw_center_fit_text(key_lines[0], top_cue_r') &&
    source.includes('_draw_center_fit_text(key_lines[1], bottom_cue_r'),
    'Long-cue result/route/next-action two-line contract missing');
  // Cargo clock is a player-visible cue, not a QA shortcut: keep the
  // count first to survive clipping and emphasize genuine <=3s urgency.
  const cargoPanel=source.slice(source.indexOf('func _draw_info_panel()'),
    source.indexOf('func _draw_intro_overlay()'));
  check(source.includes('func _draw_fit_label(text_value: String, pos: Vector2, font_size: int, color: Color, available_width: float) -> String:') &&
    source.includes('return clipped # GAME-076: expose the actual fitted/ellipsized string to passive QA.') &&
    cargoPanel.includes('var actually_drawn_countdown := _draw_fit_label(cargo_countdown') &&
    cargoPanel.includes('cargo_warning_rendered_text = actually_drawn_countdown if cargo_urgent else ""') &&
    cargoPanel.includes('int(ceil(cargo_left))') &&
    cargoPanel.includes('"%02ds LEFT  ·  %s"') &&
    cargoPanel.includes('_draw_fit_label(cargo_countdown') &&
    cargoPanel.includes('cargo_left <= 3.0') &&
    cargoPanel.includes('Color("#ff5877") if cargo_urgent') &&
    cargoPanel.includes('Color("#ff9dab")') &&
    cargoPanel.includes('"%02ds LEFT!  HURRY  ·  %s"') &&
    // On narrow viewports HURRY must not be silently truncated after the hub.
    cargoPanel.includes('var countdown_font_size := _font_size(21.0) if cargo_urgent else _font_size(17.0)') &&
    cargoPanel.includes('ui_font.get_string_size(cargo_countdown, HORIZONTAL_ALIGNMENT_LEFT, -1, countdown_font_size).x > countdown_text_width') &&
    cargoPanel.includes('"%02ds! HURRY"') &&
    cargoPanel.includes('"%02ds!"') &&
    cargoPanel.includes('info_rect.size.x < _ui_px(400.0)') &&
    cargoPanel.includes('cargo_target_label = HUB_SHORT[cargo_target]') &&
    cargoPanel.includes('var warning_chip := Rect2(') &&
    // GAME-076: the slow visual urgency pulse must remain render-only.
    cargoPanel.includes('var warning_pulse := 0.5 + 0.5 * sin(elapsed * 3.5)') &&
    cargoPanel.includes('draw_rect(warning_chip.grow(_ui_px(2.0)), Color(1.0, 0.87, 0.55, 0.45 + 0.4 * warning_pulse), false, _ui_px(2.0))') &&
    cargoPanel.includes('_rounded_box(warning_chip, Color("#8b2030"), Color("#fff0aa"), 7, 2)') &&
    cargoPanel.includes('_draw_fit_label(cargo_countdown, Vector2(x, y), countdown_font_size,') &&
    cargoPanel.includes('cargo_left / _cargo_limit()'),
    'Visible cargo countdown / <=3s warning contract missing');
  // GAME-076: first mistimed novice tap is a one-time hint, never a QA cheat.
  check(source.includes('not novice_miss_guard_used and deliveries == 0 and PLAY_TIME - time_left <= 30.0') &&
    source.includes('novice_miss_guard_used = true') &&
    source.includes('novice_miss_guard_used = false') &&
    source.includes('"novice_guard_used": novice_miss_guard_used') &&
    source.includes('FIRST TAP GUIDE · ENERGY SAVED'),
    'Novice one-time no-penalty timing hint contract missing');
  // GAME-076: Intro must say WHERE to press, not only "tap the screen".
  // This is a source contract; phone legibility still needs a human on-device check.
  const introSource=source.slice(source.indexOf('func _draw_intro_overlay()'),
    source.indexOf('func _draw_result_overlay()'));
  check(introSource.includes('var step_font := _font_size(16.0 if short_panel else 18.0)') &&
    introSource.includes('2  緑の交差点でTAP → 乗換') &&
    introSource.includes('3  同じ印のHUBでTAP → 配達'),
    'First-30s intro must explain the green crossing and matching-symbol delivery');
  return {result:'PASS_STATIC',labels:results,minimumContrast:7,
    cargoDeadline:'SOURCE_CONTRACT_ONLY: seconds first; last 3 seconds show HURRY text and contrasting frame; physical legibility requires device review',
    longCueBoundary:'SOURCE_CONTRACT_ONLY: two-line priority summary; human legibility not yet verified',
    realDevice:'NOT_VERIFIED'};
}

// GAME-076: turn passive 75ms RUSH snapshots into a comparable diagnostic.
// A sample can miss a short legal tap window; absence of a sample is NOT proof
// of an illegal tap. All inputs, game physics and scoring remain unchanged.
function summarizeRushTrace(trace, inputTimings) {
  const samples=trace && Array.isArray(trace.samples) ? trace.samples : [];
  const rush=samples.filter(x => x && x.state==='playing' &&
    x.orbit===0 && x.deliveries===1 &&
    Number.isFinite(x.angle) && Number.isFinite(x.wallMs));
  // QA-only trigger/sampling subset, NOT the game-physics acceptance window.
  const lo=4.31, hi=4.47;
  const physicsSource=fs.readFileSync('p021-game/sources/orbit-switch-courier-godot/Main.gd','utf8');
  const switchWidth=physicsSource.match(/^const SWITCH_WINDOW\s*:=\s*(\d+(?:\.\d+)?)/m);
  check(switchWidth,'GAME-076: unable to read the actual SWITCH_WINDOW from Godot source');
  const physicsHalfWidth=Number(switchWidth[1]);
  const physicsAcceptanceBandRad=[
    Number((4.50-physicsHalfWidth).toFixed(3)),
    Number((4.50+physicsHalfWidth).toFixed(3))
  ];
  check(lo>=physicsAcceptanceBandRad[0] && hi<=physicsAcceptanceBandRad[1],
    'GAME-076: QA RUSH observation band escaped the genuine switch acceptance window');
  let validSamples=0, bandVisits=0, skippedBandSamples=0, maxGapMs=0;
  let previous=null, previousInside=false;
  for (const x of rush) {
    const inside=x.angle>=lo && x.angle<=hi;
    if (inside) validSamples++;
    if (inside && !previousInside) bandVisits++;
    if (previous) {
      maxGapMs=Math.max(maxGapMs,x.wallMs-previous.wallMs);
      // Forward-angle leap across the FULL observation band: QA sampling gap
      // rather than proof the physical game crossing was not reachable.
      if (previous.angle<lo && x.angle>hi && x.angle-previous.angle<1.4)
        skippedBandSamples++;
    }
    previous=x; previousInside=inside;
  }
  const click=(inputTimings||[]).find(t => t.label==='RUSH 0->1');
  const nearest=click && rush.length ? rush.reduce((best,x) =>
    Math.abs(x.wallMs-click.observedWallMs) <
      Math.abs(best.wallMs-click.observedWallMs) ? x : best) : null;
  return {kind:'READ_ONLY_DIAGNOSTIC_NOT_PASS_CRITERION',
    observationBandRad:[lo,hi],
    physicsAcceptanceBandRad,
    observationBandMeaning:'QA_ONLY_TRIGGER_AND_SAMPLING_SUBSET_NOT_PASS_CRITERION',
    samplePeriodMs:trace?.samplePeriodMs||75,
    totalTraceSamples:samples.length,rushOrbit0Samples:rush.length,
    observationBandSamples:validSamples,observationBandVisits:bandVisits,
    forwardBandSkipsWithoutSample:skippedBandSamples,
    maxRushSampleGapMs:maxGapMs,
    clickTiming:click?{observedWallMs:click.observedWallMs,
      inputFinishedWallMs:click.inputFinishedWallMs,
      inputCallMs:click.inputCallMs}:null,
    nearestReadOnlySampleToClick:nearest?{angle:nearest.angle,
      cargoLeft:nearest.cargoLeft,wallOffsetMs:nearest.wallMs-click.observedWallMs}:null,
    interpretation:'Sample proximity is approximate; use genuine switch+energy assertions for PASS'};
}

async function snapshot(page) { return page.evaluate(() => window.__P021_ORBIT || null); }
async function until(page, predicate, stage, waitMs=16000, arg=null) {
  // GAME-076: poll wider physics-valid real-input windows on wall time rather than animation
  // frames. Tablet WASM rendering can delay rAF; this ONLY observes state and
  // leaves all deliveries/transfers to real Playwright mouse/touch input.
  const inputWindow = /(?:crossing|target HUB|natural switch|natural delivery)/i.test(stage);
  await page.waitForFunction(predicate,arg,{timeout:waitMs,polling:inputWindow?20:'raf'})
    .catch(e=>{throw new Error(stage+': '+e.message);});
}
async function inputAt(page,t,p) {
  check(p && Number.isFinite(p.x) && Number.isFinite(p.y),'Physical input point missing');
  if(t.input==='touch') await page.touchscreen.tap(p.x,p.y);
  else await page.mouse.click(p.x,p.y);
}
async function input(page,t) {
  // Cache gameplay position: no DOM queries on the timing-critical path.
  check(t.hitPoint,'Hit point was not prepared');
  await inputAt(page,t,t.hitPoint);
}
function physicalRect(r,c,d) {
  check(r && r.length===4,'Missing UI rectangle');
  return {x:c.x+r[0]*c.width/d.viewport_w,y:c.y+r[1]*c.height/d.viewport_h,
    width:r[2]*c.width/d.viewport_w,height:r[3]*c.height/d.viewport_h};
}
// GAME-076: deterministic cargo sequence, but EVERY score and orbital change is
// achieved using real mouse/touch at ordinary runtime windows (no QA commands).
async function physicalSwitch(page,t,from,to,lo,hi,label) {
  await until(page,(a)=>{const x=window.__P021_ORBIT;return x&&x.state==='playing'&&
    x.orbit===a.from&&x.angle>=a.lo&&x.angle<=a.hi;},label+' crossing',18000,{from,lo,hi});
  // Record real Playwright input latency without sampling the game on the critical path.
  // These are passive wall-clock timestamps, not simulated input or state writes.
  const timing={label,action:'switch',from,to,observedWallMs:Date.now()};
  if (!Array.isArray(t.inputTimings)) t.inputTimings=[];
  t.inputTimings.push(timing);
  await input(page,t);
  timing.inputFinishedWallMs=Date.now();
  timing.inputCallMs=timing.inputFinishedWallMs-timing.observedWallMs;
  await until(page,(a)=>{const x=window.__P021_ORBIT;return x&&x.orbit===a.to;},label+' transfer',3500,{to});
  timing.transferConfirmedWallMs=Date.now();
  const d=await snapshot(page);
  check(d.energy===3&&d.state==='playing',label+' lost energy');
  return {action:'transfer',label,orbit:d.orbit,angle:d.angle,energy:d.energy};
}
async function physicalDeliver(page,t,target,lo,hi,total,label) {
  await until(page,(a)=>{const x=window.__P021_ORBIT;return x&&x.state==='playing'&&
    x.orbit===a.target&&x.cargo_target===a.target&&x.angle>=a.lo&&x.angle<=a.hi;},
    label+' target HUB',18000,{target,lo,hi});
  await input(page,t);
  await until(page,(a)=>{const x=window.__P021_ORBIT;return x&&x.deliveries===a.total;},
    label+' actual delivery',3500,{total});
  const d=await snapshot(page);
  check(d.energy===3&&d.state==='playing'&&d.score>0,label+' scoring/energy failed');
  return {action:'delivery',label,deliveries:d.deliveries,score:d.score,
    orbit:d.orbit,mission:d.mission_name,limit:d.cargo_limit,energy:d.energy};
}
async function run(){
  const visualContract=verifyGuideContrast();
  fs.mkdirSync(dir,{recursive:true});
  const browser=await chromium.launch({headless:true});
  const results=[];
  const layoutSweep=[];
  // Keep a read-only, machine-parseable checkpoint on disk. GitHub Actions may
  // cancel a long four-viewport run before the final results.json is written.
  // This does not alter game state, scoring, or any physical input.
  const checkpoint=(phase,activeViewport)=>fs.writeFileSync(
    dir+'/results-checkpoint.json',JSON.stringify({
      task:'GAME-076',game:'GAME-G030',status:'PARTIAL_CHECKPOINT_NOT_FINAL',
      phase,activeViewport,completedViewportCount:results.length,
      expectedViewportCount:targets.length,viewports:results
    },null,2));
  checkpoint('STARTING',null);
  try {
    for(const t of targets){
      checkpoint('VIEWPORT_RUNNING',t.name);
      const context=await browser.newContext({
        viewport:{width:t.width,height:t.height},deviceScaleFactor:1,
        isMobile:t.width<=844,hasTouch:true
      });
      const page=await context.newPage(), errors=[];
      page.on('pageerror',e=>errors.push('pageerror '+e.message));
      page.on('console',m=>{if(m.type()==='error')errors.push('console '+m.text());});
      page.on('requestfailed',r=>errors.push('request '+r.url()));
      const evidence={viewport:t.name,size:t.width+'x'+t.height,input:t.input,
        qaCommand:'NEVER USED',stateOverride:'NONE',status:'FAIL'};
      try {
        await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.ready,'ready',120000);
        let d=await snapshot(page);
        check(d.child_id==='GAME-G030' && d.state==='intro' && d.qa_mode,'Incorrect initial game');
        check(fits(d.field,d.viewport_w,d.viewport_h) && fits(d.info,d.viewport_w,d.viewport_h),
          'Field or info overflows game viewport');
        const c=await page.locator('#canvas').boundingBox();
        check(c && c.x>=-2 && c.y>=-2 && c.x+c.width<=t.width+2 && c.y+c.height<=t.height+2,'Canvas overflows');
        // Record the novice intro on all four viewport sizes.
        await page.screenshot({path:dir+'/'+t.name+'-intro.png'});
        const soundBox=physicalRect(d.sound_rect,c,d);
        const hudBox=physicalRect(d.hud_rect,c,d);
        const hubBox=physicalRect(d.hub_rect,c,d);
        // Compact landscape intentionally hides GAME HUB; other layouts must
        // show a distinct, non-overlapping second header row.
        if(c.height>520) {
          check(hubBox.y+hubBox.height <= hudBox.y-3,
            'GAME HUB overlaps the HUD: '+JSON.stringify({hubBox,hudBox}));
        }
        check(soundBox.width>=44&&soundBox.height>=44,
          'SOUND tap target <44px: '+JSON.stringify(soundBox));
        check(soundBox.x>=0 && soundBox.y>=0 &&
          soundBox.x+soundBox.width<=t.width+2&&soundBox.y+soundBox.height<=t.height+2,
          'SOUND rectangle overflows physical browser viewport');
        const soundPoint={x:soundBox.x+soundBox.width/2,y:soundBox.y+soundBox.height/2};
        check(d.sound===true,'SOUND should default to ON');
        // Real physical interaction with the visible canvas button, no QA commands.
        await inputAt(page,t,soundPoint);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.sound===false,'SOUND OFF');
        d=await snapshot(page);
        check(d.state==='intro' && !d.audio_playing,'SOUND OFF should mute immediately and not start the game');
        await page.screenshot({path:dir+'/'+t.name+'-sound-off.png'});
        await page.waitForTimeout(170);
        await inputAt(page,t,soundPoint);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.sound===true,'SOUND ON');
        // Internal player start is observable; actual speaker output/volume needs a human.
        const heardByEngine=await page.waitForFunction(
          ()=>window.__P021_ORBIT && window.__P021_ORBIT.sound &&
            window.__P021_ORBIT.audio_playing===true,
          null,{timeout:1200,polling:'raf'}).then(()=>true).catch(()=>false);
        evidence.audio={soundOff:true,soundOn:true,enginePlayerObserved:heardByEngine,
          physicalOutput:'NOT VERIFIED – requires real-device audible check'};
        await page.screenshot({path:dir+'/'+t.name+'-sound-on.png'});
        await page.waitForTimeout(170);
        // Cache gameplay coordinates before time-critical physics; never override state.
        t.hitPoint={
          x:c.x+(d.field[0]+d.field[2]/2)*c.width/d.viewport_w,
          y:c.y+(d.field[1]+d.field[3]/2)*c.height/d.viewport_h
        };
        check(t.hitPoint.x>0 && t.hitPoint.x<t.width &&
          t.hitPoint.y>0 && t.hitPoint.y<t.height,'Physical input point outside viewport');
        // A physical touch/click starts the round.
        await input(page,t);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.state==='playing','start');
        d=await snapshot(page);
        check(d.orbit===1 && d.cargo_target===0 && d.energy===3 && d.mission_tier===0 && d.cargo_limit===16,'Unexpected initial route, cargo or double start input');
        await page.screenshot({path:dir+'/'+t.name+'-playing.png'});
        // Orbit 1 angular velocity is negative. Trigger at 4.38..4.68 inside the actual 4.50 +/- 0.23 physics window.
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&x.state==='playing'&&
          x.orbit===1&&x.angle>=4.38&&x.angle<=4.68;},'approach natural switch');
        evidence.switchTrigger='4.38..4.68 rad, real-time observation within actual crossing window';
        await input(page,t);
        evidence.switchAfter=await snapshot(page);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.orbit===0,'real orbit transfer',4000);
        d=await snapshot(page);
        check(d.energy===3,'Energy lost at switch');
        evidence.transfer={orbit:d.orbit,energy:d.energy};
        // Orbit 0 angular velocity is positive; Hub 0 is at 1.48 radians.
        // The actual HUB0 scoring window is 1.48 +/- 0.23 (HUB_WINDOW=0.23).
        // Observe a physics-valid 1.31..1.60 band instead of a narrow sliver that
        // can be skipped when the browser or a tablet frame is delayed.
        // Delivery and full energy are still required: never force physics/state.
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&x.state==='playing'&&
          x.orbit===0&&x.cargo_target===0&&x.angle>=1.31&&x.angle<=1.60;},'approach natural delivery');
        evidence.hubTrigger='1.31..1.60 rad, real-time observation within natural HUB window';
        await input(page,t);
        evidence.hubAfter=await snapshot(page);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.deliveries>=1,'real delivery',4000);
        d=await snapshot(page);
        check(d.deliveries===1&&d.score>0&&d.energy===3,'Natural score/delivery missing');
        check(d.mission_tier===1 && d.mission_name==='RUSH' && d.cargo_limit===14,
          'Delivery did not unlock the harder RUSH route');
        evidence.delivery={deliveries:d.deliveries,score:d.score,energy:d.energy,
          progression:{route:d.mission_tier,name:d.mission_name,cargoLimit:d.cargo_limit,cue:d.cue_text}};
        await page.screenshot({path:dir+'/'+t.name+'-route-rush.png'});
        // Stage RUSH -> NIGHT -> ACE by actual taps at crossings and HUBs.
        // Physical input paths: 0 -> 1 -> HUB1; 1 -> 2 -> HUB2 (NIGHT at 3);
        // 2 -> 1 -> 0 -> HUB0; 0 -> 1 -> HUB1; 1 -> 2 -> HUB2 (ACE at 6).
        evidence.routeMoves=[];
        // Orbit 0 moves forward at 1.12rad/s. Trigger within a narrow QA subset of the actual 4.50 +/- 0.23 game window.
        // The former 4.35..4.57 band could observe too late for a real tablet tap.
        // GAME-076: attempt1 crossed 4.367->4.534 and 4.363->4.616 without
        // hitting the narrow 4.32..4.44 observer; a third crossing at cargoLeft=0.13
        // then lost energy. Observe 4.31..4.47, a QA trigger subset inside the actual 4.50 +/- 0.23
        // game physics window, as NIGHT 0->1 already does. Actual mouse/touch,
        // delivery deadline and energy assertions remain unchanged.
        await page.evaluate(() => {
          if (window.__P021_RUSH_TRACE_TIMER) clearInterval(window.__P021_RUSH_TRACE_TIMER);
          window.__P021_RUSH_TRACE=[];
          // GAME-076 attempt2: capture the ACTUAL browser pointerdown angle.
          // Passive capture only: never preventDefault, stop propagation, synthesize
          // success, override orbit/energy, or change the physics acceptance window.
          if (window.__P021_RUSH_POINTER_CAPTURE)
            document.removeEventListener('pointerdown',window.__P021_RUSH_POINTER_CAPTURE,true);
          window.__P021_RUSH_POINTERS=[];
          window.__P021_RUSH_POINTER_CAPTURE=(event) => {
            const x=window.__P021_ORBIT, a=window.__P021_RUSH_POINTERS;
            if (!x || !Array.isArray(a)) return;
            a.push({event:event.type,pointerType:event.pointerType||'unknown',
              wallMs:Date.now(),monoMs:Math.round(performance.now()),
              state:x.state,orbit:x.orbit,angle:Math.round(x.angle*1000)/1000,
              cargoLeft:Math.round(x.cargo_left*100)/100,energy:x.energy,
              deliveries:x.deliveries});
            if(a.length>12)a.shift();
          };
          document.addEventListener('pointerdown',window.__P021_RUSH_POINTER_CAPTURE,true);
          window.__P021_RUSH_TRACE_TIMER=setInterval(() => {
            const x=window.__P021_ORBIT, a=window.__P021_RUSH_TRACE;
            if (!x || !Array.isArray(a)) return;
            a.push({wallMs:Date.now(),monoMs:Math.round(performance.now()),
              state:x.state,orbit:x.orbit,angle:Math.round(x.angle*1000)/1000,
              cargoLeft:Math.round(x.cargo_left*100)/100,
              timeLeft:Math.round(x.time_left*100)/100,
              energy:x.energy,deliveries:x.deliveries});
            if (a.length>300) a.shift();
          },75);
        });
        try {
          evidence.routeMoves.push(await physicalSwitch(page,t,0,1,4.31,4.47,'RUSH 0->1'));
        } finally {
          // Capture whether QA timed out BEFORE the valid crossing was reached.
          // The game itself, click path, deadlines and acceptance thresholds are untouched.
          try {
            evidence.rushTelemetry=await page.evaluate(() => {
              if (window.__P021_RUSH_TRACE_TIMER) clearInterval(window.__P021_RUSH_TRACE_TIMER);
              return {samplePeriodMs:75,readOnly:true,samples:window.__P021_RUSH_TRACE||[]};
            });
          } catch (traceErr) {
            evidence.rushTelemetryError=String(traceErr.message);
          }
          // Pointerdown capture is read-only and does not count as a passing
          // transfer; every viewport must still satisfy real orbit + energy checks.
          try {
            evidence.rushPointerCapture=await page.evaluate(() => {
              if(window.__P021_RUSH_POINTER_CAPTURE) {
                document.removeEventListener('pointerdown',window.__P021_RUSH_POINTER_CAPTURE,true);
                window.__P021_RUSH_POINTER_CAPTURE=null;
              }
              return {kind:'PASSIVE_POINTER_EVENT_NOT_PASS_CRITERION',
                events:window.__P021_RUSH_POINTERS||[]};
            });
          } catch (pointerErr) {
            evidence.rushPointerCaptureError=String(pointerErr.message);
          }
          evidence.rushDiagnostic=summarizeRushTrace(evidence.rushTelemetry,t.inputTimings);
          evidence.rushDiagnostic.actualPointerdown=evidence.rushPointerCapture||
            {kind:'UNAVAILABLE'};
        }
        evidence.routeMoves.push(await physicalDeliver(page,t,1,3.46,3.76,2,'RUSH HUB1'));
        evidence.routeMoves.push(await physicalSwitch(page,t,1,2,2.41,2.66,'RUSH 1->2'));
        // GAME-076: passive, bounded telemetry to diagnose missed NIGHT HUB0 on tablets.
        // It never sends commands or mutates the Godot game state.
        await page.evaluate(() => {
          if (window.__P021_NIGHT_TRACE_TIMER) clearInterval(window.__P021_NIGHT_TRACE_TIMER);
          window.__P021_NIGHT_TRACE=[];
          window.__P021_NIGHT_TRACE_TIMER=setInterval(() => {
            const x=window.__P021_ORBIT;
            if (!x || x.state!=='playing') return;
            const trace=window.__P021_NIGHT_TRACE;
            if (!Array.isArray(trace)) return;
            trace.push({ms:Math.round(performance.now()),wallMs:Date.now(),orbit:x.orbit,
              angle:Math.round(x.angle*1000)/1000,cargo:x.cargo_target,
              cargoLeft:Math.round(x.cargo_left*100)/100,
              energy:x.energy,deliveries:x.deliveries});
            if (trace.length>320) trace.shift();
          },75);
        });
        evidence.routeMoves.push(await physicalDeliver(page,t,2,5.02,5.29,3,'NIGHT HUB2'));
        d=await snapshot(page);
        check(d.mission_tier===2&&d.mission_name==='NIGHT'&&d.cargo_limit===12,
          'Natural 3 deliveries did not unlock NIGHT/12 seconds');
        evidence.night={deliveries:d.deliveries,score:d.score,limit:d.cargo_limit,
          cue:d.cue_text,energy:d.energy};
        // Important: the next 2->1 crossing arrives ~0.5s after delivery #3.
        // Awaiting a heavyweight screenshot here makes larger tablet viewports miss
        // that crossing, forcing a whole extra orbit and expiring the NIGHT cargo.
        // Record the genuine route milestone in evidence.night; keep screenshots
        // for non-critical states instead of perturbing natural timed gameplay.
        evidence.routeMoves.push(await physicalSwitch(page,t,2,1,5.57,5.82,'NIGHT 2->1'));
        evidence.routeMoves.push(await physicalSwitch(page,t,1,0,4.38,4.68,'NIGHT 1->0'));
        // GAME-076: Use a broad 1.31..1.60 band inside the real HUB0 +/- 0.23 window.
        evidence.routeMoves.push(await physicalDeliver(page,t,0,1.31,1.60,4,'NIGHT HUB0'));
        // GAME-076: Tablet-portrait CI run 38311488593 missed the 4.467/4.370 rad
        // orbit-0 crossings with a narrow 4.32..4.44 observer. Observe 4.31..4.47
        // within the real 4.50 +/- 0.23 rad switch window (no success bypass).
        // Input remains a physical touch/mouse event; score and energy are asserted.
        evidence.routeMoves.push(await physicalSwitch(page,t,0,1,4.31,4.47,'NIGHT 0->1'));
        evidence.routeMoves.push(await physicalDeliver(page,t,1,3.46,3.76,5,'NIGHT HUB1'));
        evidence.routeMoves.push(await physicalSwitch(page,t,1,2,2.41,2.66,'NIGHT 1->2'));
        evidence.routeMoves.push(await physicalDeliver(page,t,2,5.02,5.29,6,'ACE HUB2'));
        d=await snapshot(page);
        check(d.mission_tier===3&&d.mission_name==='ACE'&&d.cargo_limit===10,
          'Natural 6 deliveries did not unlock ACE/10 seconds');
        evidence.ace={deliveries:d.deliveries,score:d.score,limit:d.cargo_limit,
          cue:d.cue_text,energy:d.energy};
        await page.screenshot({path:dir+'/'+t.name+'-route-ace.png'});
        // Three real misses away from HUB and crossings; no success shortcuts.
        // Orbit 2 after HUB2 rotates forward; 0.56..0.70 is safe even
        // as we send three taps, unlike 5.72 where a bridge is nearby.
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&x.state==='playing'&&
          x.orbit===2&&x.angle>=0.55&&x.angle<=1.40;},'safe miss zone after ACE');
        for(let energy=2;energy>=0;energy--){
          await page.waitForTimeout(170);
          await input(page,t);
          await page.waitForFunction(n=>window.__P021_ORBIT && window.__P021_ORBIT.energy===n,
            energy,{timeout:7000,polling:'raf'});
          if(energy===2)await page.screenshot({path:dir+'/'+t.name+'-miss-feedback.png'});
        }
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.state==='result','RESULT');
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&x.retry_rect&&x.retry_rect[3]>0;},
          'RETRY drawn');
        d=await snapshot(page);
        const retryBox=physicalRect(d.retry_rect,c,d);
        check(retryBox.width>=44&&retryBox.height>=44,
          'RETRY tap target <44px: '+JSON.stringify(retryBox));
        evidence.targets={soundCssPixels:{w:Math.round(soundBox.width),h:Math.round(soundBox.height)},
          retryCssPixels:{w:Math.round(retryBox.width),h:Math.round(retryBox.height)}};
        const score=d.score;
        check(score>0&&d.best>=score,'RESULT score/BEST invalid');
        evidence.result={score,best:d.best,energy:d.energy};
        await page.screenshot({path:dir+'/'+t.name+'-result.png'});
        // Retry is a separate human action, not the browser's duplicate pointer event.
        await page.waitForTimeout(170);
        await inputAt(page,t,{x:retryBox.x+retryBox.width/2,y:retryBox.y+retryBox.height/2});
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.state==='intro','RETRY');
        await page.screenshot({path:dir+'/'+t.name+'-retry.png'});
        d=await snapshot(page);
        check(d.best>=score&&d.score===0&&d.energy===3,'RETRY did not reset while retaining best');
        await page.reload({waitUntil:'domcontentloaded',timeout:120000});
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.ready,'reload',120000);
        d=await snapshot(page);
        const storage=await page.evaluate(()=>window.localStorage.getItem('p021-g030-best'));
        check(d.state==='intro'&&d.best>=score&&Number(storage)>=score,'BEST not recovered after reload');
        evidence.restoredBest=d.best;
        evidence.localStorageBest=Number(storage);
        await input(page,t);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.state==='playing','replay after reload');
        await page.screenshot({path:dir+'/'+t.name+'-replay.png'});
        // GAME-076: an actual off-window tap in the first 30 seconds should
        // teach first-time players instead of consuming one energy. This is a
        // NORMAL user interaction and never changes state from the QA bridge.
        // Orbit 1 at 4.0..4.2 rad is safely outside all HUB/switch windows.
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&
          x.state==='playing'&&x.orbit===1&&x.deliveries===0&&
          x.angle>=4.0&&x.angle<=4.2;},'novice safe off-window tap',9500);
        await input(page,t);
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&
          x.state==='playing'&&x.novice_guard_used===true&&
          x.energy===3&&x.deliveries===0;},'novice energy-preserving guide',3500);
        d=await snapshot(page);
        check(d.cue_text.includes('FIRST TAP GUIDE') && d.score===0,
          'Novice hint was not visible or unexpectedly scored');
        await page.screenshot({path:dir+'/'+t.name+'-novice-first-tap-guide.png'});
        evidence.noviceFirstTapGuide={status:'PASS',input:'real touch/mouse',
          energyAfter:3,deliveriesAfter:0,guardConsumed:true,
          hint:d.cue_text,screenshot:t.name+'-novice-first-tap-guide.png'};
        // GAME-076: independent cue-overflow image fixture, not a scoring cheat.
        // Only an extra QA query flag substitutes the banner DRAWN TEXT.
        // We start by a real tap and verify progress remains at zero.
        await page.goto(url+'&cue_stress=1',{waitUntil:'domcontentloaded',timeout:120000});
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.ready,'read-only long-cue ready',120000);
        d=await snapshot(page);
        check(d.qa_mode && d.cue_stress && d.state==='intro',
          'QA-only long-cue flag unavailable');
        const stressCanvas=await page.locator('#canvas').boundingBox();
        check(stressCanvas,'QA-only long-cue canvas unavailable');
        t.hitPoint={
          x:stressCanvas.x+(d.field[0]+d.field[2]/2)*stressCanvas.width/d.viewport_w,
          y:stressCanvas.y+(d.field[1]+d.field[3]/2)*stressCanvas.height/d.viewport_h
        };
        check(d.deliveries===0 && d.score===0,
          'QA display fixture affected delivery or score before input');
        await input(page,t);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.state==='playing',
          'read-only long-cue normal physical start');
        await page.waitForTimeout(110);
        d=await snapshot(page);
        check(d.cue_stress && d.state==='playing' && d.score===0 && d.deliveries===0,
          'QA display fixture altered game progress or did not render');
        // Confirm the renderer selected the long cue and preserved its two critical lines.
        // QA only reads Godot display telemetry; this cannot advance a delivery or score.
        check(typeof d.qa_visible_cue==='string' &&
          d.qa_visible_cue.includes('NEXT ACTION:') &&
          d.qa_visible_cue.includes('EXTRA-LONG TEST STATUS') &&
          d.qa_priority_top.includes('ROUTE NIGHT') &&
          d.qa_priority_next.includes('TAP NOW'),
          'Long-cue display priorities missing: '+JSON.stringify({top:d.qa_priority_top,next:d.qa_priority_next}));
        await page.screenshot({path:dir+'/'+t.name+'-cue-stress.png'});
        evidence.cueStress={result:'CAPTURED',stage:'natural real-input playing',
          deliveries:d.deliveries,score:d.score,readOnlyDisplay:true,
          screenshot:t.name+'-cue-stress.png',
          physicalTextLegibility:'REQUIRES INDEPENDENT VISUAL REVIEW'};
        // GAME-076: capture the *actual* last-3-seconds warning on the
        // ordinary game UI, after a physical START tap and real elapsed time.
        // This intentionally does not change the clock, score, state, physics,
        // success conditions, or any game's internal values.
        await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.ready,
          'normal deadline view ready',120000);
        d=await snapshot(page);
        check(d.state==='intro' && d.cargo_left>3,
          'Normal countdown scenario did not begin from intro');
        const deadlineCanvas=await page.locator('#canvas').boundingBox();
        check(deadlineCanvas,'Normal countdown canvas unavailable');
        const deadlinePoint={
          x:deadlineCanvas.x+(d.field[0]+d.field[2]/2)*deadlineCanvas.width/d.viewport_w,
          y:deadlineCanvas.y+(d.field[1]+d.field[3]/2)*deadlineCanvas.height/d.viewport_h
        };
        await inputAt(page,t,deadlinePoint);
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&
          x.state==='playing' && x.cargo_left>3 && x.deliveries===0;},
          'normal countdown after genuine start');
        await page.waitForFunction(()=>{const x=window.__P021_ORBIT;return x&&
          x.state==='playing' && x.cargo_left<=2.95 && x.cargo_left>=1.5 &&
          x.energy===3 && x.deliveries===0;},
          null,{timeout:20000,polling:50});
        const warningBefore=await snapshot(page);
        const warningFile=t.name+'-cargo-warning-3s.png';
        await page.screenshot({path:dir+'/'+warningFile});
        const warningAfter=await snapshot(page);
        check(warningBefore.cargo_left>0 && warningBefore.cargo_left<=3.0 &&
          warningAfter.state==='playing' && warningAfter.cargo_left>0 &&
          warningAfter.deliveries===0 && warningAfter.energy===3,
          'Last-three-seconds image did not remain inside live warning window');
        evidence.cargoWarning={result:'CAPTURED_UNREVIEWED',
          method:'physical START, natural elapsed game time, screenshot while cargo_left<=3',
          secondsBefore:warningBefore.cargo_left,
          secondsAfter:warningAfter.cargo_left,deliveries:warningAfter.deliveries,
          energy:warningAfter.energy,screenshot:warningFile,
          visualWarningPass:'NOT VERIFIED - inspect actual PNG independently',
          physicalLegibility:'HUMAN GATE'};
        check(errors.length===0,'Browser console/runtime errors: '+errors.join(' | '));
        // Stop the diagnostic observer before releasing this browser context.
        await page.evaluate(() => {
          if (window.__P021_NIGHT_TRACE_TIMER) clearInterval(window.__P021_NIGHT_TRACE_TIMER);
        });
        evidence.status='PASS';
      }catch(err){
        evidence.failure=err.message;
        evidence.browserErrors=errors;
        // Capture read-only trace for ANY NIGHT failure, including energy loss before HUB0.
        if (/NIGHT/.test(evidence.failure)) {
          try {
            evidence.nightTelemetry=await page.evaluate(() => {
              if (window.__P021_NIGHT_TRACE_TIMER) clearInterval(window.__P021_NIGHT_TRACE_TIMER);
              return window.__P021_NIGHT_TRACE||[];
            });
          } catch (traceErr) { evidence.nightTelemetryError=String(traceErr); }
        }
        try{evidence.lastSnapshot=await snapshot(page);
          await page.screenshot({path:dir+'/'+t.name+'-FAIL.png'});}catch(e){
            evidence.screenshotError=String(e);
          }
      }finally{
        evidence.actionTimings=t.inputTimings||[];
        results.push(evidence);
        checkpoint('VIEWPORT_COMPLETED',t.name);
        await context.close();
      }
    }


    // GAME-076: expand the viewport matrix without tripling the time-critical
    // NIGHT/ACE route runs. QA state is observed only; no synthetic deliveries.
    for(const t of layoutTargets){
      const context=await browser.newContext({
        viewport:{width:t.width,height:t.height},deviceScaleFactor:1,
        isMobile:t.width<=844,hasTouch:true
      });
      const page=await context.newPage();
      const failures=[];
      page.on('pageerror',e=>failures.push('pageerror '+e.message));
      page.on('console',m=>{if(m.type()==='error')failures.push('console '+m.text());});
      page.on('requestfailed',r=>failures.push('request '+r.url()));
      const proof={viewport:t.name,size:t.width+'x'+t.height,
        mode:'INTRO_AND_NATURAL_START_GEOMETRY',physicalLegibility:'HUMAN GATE',status:'FAIL'};
      try{
        await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
        await until(page,()=>window.__P021_ORBIT&&window.__P021_ORBIT.ready,
          'responsive ready '+t.name,120000);
        const d=await snapshot(page);
        check(d.child_id==='GAME-G030' && d.state==='intro' && d.qa_mode,
          'Responsive sweep did not load intro: '+t.name);
        check(fits(d.field,d.viewport_w,d.viewport_h) &&
          fits(d.info,d.viewport_w,d.viewport_h),
          'Responsive field/info overflow: '+t.name);
        const c=await page.locator('#canvas').boundingBox();
        check(c && c.x>=-2 && c.y>=-2 &&
          c.x+c.width<=t.width+2 && c.y+c.height<=t.height+2,
          'Responsive canvas overflow: '+t.name);
        const sound=physicalRect(d.sound_rect,c,d);
        check(sound.width>=44 && sound.height>=44 &&
          sound.x>=-2 && sound.y>=-2 &&
          sound.x+sound.width<=t.width+2 && sound.y+sound.height<=t.height+2,
          'Responsive SOUND target too small/overflows: '+t.name+' '+JSON.stringify(sound));
        // Read-only layout contract: the onboarding caption/title must stay
        // left of the SOUND button even on a 320px portrait phone.
        // Header text uses _draw_fit_label, constrained to this measured lane.
        const header=physicalRect(d.header_text_region_rect,c,d);
        const headerSoundGap=sound.x-(header.x+header.width);
        check(header.width>=100 && header.x>=-2 && header.y>=-2 &&
          header.y+header.height<=t.height+2 && headerSoundGap>=8,
          'Responsive header overlaps SOUND: '+t.name+' '+JSON.stringify({header,sound,gap:headerSoundGap}));
        proof.headerSoundSpacing={source:'GODOT_RENDERED_RESERVED_TEXT_LANE_READ_ONLY',
          gapCssPx:Math.round(headerSoundGap*100)/100,minimumCssPx:8,
          headerTextLane:header,soundButton:sound};
        // GAME-076: catch the clipped third intro instruction on a 320px
        // portrait phone, independent of the previously green field/HUD test.
        // Observe Godot's actually drawn line + button rectangles, not a
        // JS approximation. Never issue QA commands or alter game state.
        // GAME-076: verify *all* intro lines, not only the final line vs START.
        // Geometry comes from Godot's actual draw rectangles (read-only telemetry).
        const introTitle=physicalRect(d.intro_title_rect,c,d);
        const introFirst=physicalRect(d.intro_first_step_rect,c,d);
        const introSecond=physicalRect(d.intro_second_step_rect,c,d);
        const introStep=physicalRect(d.intro_last_step_rect,c,d);
        const introStart=physicalRect(d.intro_start_rect,c,d);
        const introField=physicalRect(d.field,c,d);
        const titleFirstGap=introFirst.y-(introTitle.y+introTitle.height);
        const firstSecondGap=introSecond.y-(introFirst.y+introFirst.height);
        const secondThirdGap=introStep.y-(introSecond.y+introSecond.height);
        const introGap=introStart.y-(introStep.y+introStep.height);
        check([introTitle,introFirst,introSecond,introStep].every(r=>r.width>0&&r.height>=12) &&
          // New compact title offset should provide ~6 CSS px, with float tolerance.
          titleFirstGap>=5.5 && firstSecondGap>=0 && secondThirdGap>=0,
          'Responsive intro title/instruction collision: '+t.name+' '+
          JSON.stringify({introTitle,introFirst,introSecond,introStep,titleFirstGap,firstSecondGap,secondThirdGap}));
        check(introStep.width>0&&introStep.height>=12&&
          introStart.width>=44&&introStart.height>=40&&introGap>=4,
          'Responsive intro line overlaps START: '+t.name+' '+
          JSON.stringify({introStep,introStart,introGap}));
        for(const [name,r] of [['title',introTitle],['first instruction',introFirst],['second instruction',introSecond],['third instruction',introStep],['start button',introStart]]){
          check(r.x>=introField.x-2&&r.y>=introField.y-2&&
            r.x+r.width<=introField.x+introField.width+2&&
            r.y+r.height<=introField.y+introField.height+2,
            'Responsive '+name+' exceeds playfield: '+t.name+' '+
            JSON.stringify({r,introField}));
        }
        proof.introAllStepSpacing={source:'GODOT_RENDERED_RECT_TELEMETRY_READ_ONLY',
          titleToStep1CssPx:Math.round(titleFirstGap*100)/100,
          minimumTitleToStep1CssPx:5.5,
          step1ToStep2CssPx:Math.round(firstSecondGap*100)/100,
          step2ToStep3CssPx:Math.round(secondThirdGap*100)/100,
          title:introTitle,step1:introFirst,step2:introSecond,step3:introStep};
        proof.introStepButtonSpacing={source:'GODOT_RENDERED_RECT_TELEMETRY_READ_ONLY',
          gapCssPx:Math.round(introGap*100)/100,minimumCssPx:4,
          lastInstruction:introStep,startButton:introStart};

        // GAME-076: rectangle spacing cannot prove that text is actually legible.
        // This read-only probe comes from the same _draw_center_fit_text path
        // used for the four intro labels, after shrink/ellipsis decisions.
        const drawnIntro=d.intro_rendered_steps;
        check(Array.isArray(drawnIntro) && drawnIntro.length===4,
          'Missing actual intro glyph evidence: '+t.name+' '+JSON.stringify(drawnIntro));
        const [titleGlyph,startGlyph,switchGlyph,deliveryGlyph]=drawnIntro;
        check(drawnIntro.every(line=>line && typeof line.text==='string' &&
          line.text.length>0 && Number.isFinite(Number(line.font_css_px))),
          'Invalid intro glyph/font evidence: '+t.name+' '+JSON.stringify(drawnIntro));
        check(!titleGlyph.ellipsized && Number(titleGlyph.font_css_px)>=12 &&
          [startGlyph,switchGlyph,deliveryGlyph].every(line=>
            !line.ellipsized && Number(line.font_css_px)>=14),
          'Intro text was ellipsized or shrunk below the minimum: '+t.name+' '+
          JSON.stringify(drawnIntro));
        check(startGlyph.text.includes('START') &&
          switchGlyph.text.includes('緑') && switchGlyph.text.includes('乗換') &&
          deliveryGlyph.text.includes('配達'),
          'Intro lost its first-action instructions: '+t.name+' '+
          JSON.stringify(drawnIntro));
        proof.introDrawnText={source:'GODOT_ACTUAL_FIT_RENDER_TEXT_READ_ONLY',
          labels:drawnIntro,minStepFontCssPx:14,
          humanInstantRecognition:'UNTESTED'};

        const hud=physicalRect(d.hud_rect,c,d);
        const hub=physicalRect(d.hub_rect,c,d);
        if(c.height>520)check(hub.y+hub.height<=hud.y-3,
          'Responsive HUB/HUD overlap: '+t.name);
        check(failures.length===0,'Responsive console/network errors: '+failures.join(' | '));
        proof.soundTarget={width:sound.width,height:sound.height};
        proof.field=d.field;
        proof.info=d.info;
        // Complement the intro-only geometry check with a real touch/mouse START.
        // This never writes Godot state and does not pretend to be a full route E2E.
        const starter={input:t.width<=568?'touch':'mouse'};
        const center={
          x:c.x+(d.field[0]+d.field[2]/2)*c.width/d.viewport_w,
          y:c.y+(d.field[1]+d.field[3]/2)*c.height/d.viewport_h
        };
        check(center.x>0&&center.x<t.width&&center.y>0&&center.y<t.height,
          'Responsive START point outside viewport: '+t.name);
        await page.screenshot({path:dir+'/'+t.name+'-layout-intro.png'});
        await inputAt(page,starter,center);
        await until(page,()=>window.__P021_ORBIT&&window.__P021_ORBIT.state==='playing',
          'responsive physical START '+t.name,20000);
        const playing=await snapshot(page);
        check(playing.state==='playing'&&playing.orbit===1&&playing.energy===3,
          'Responsive natural START state mismatch: '+t.name);
        check(fits(playing.field,playing.viewport_w,playing.viewport_h)&&
          fits(playing.info,playing.viewport_w,playing.viewport_h),
          'Responsive PLAYING field/info overflow: '+t.name);
        const playCanvas=await page.locator('#canvas').boundingBox();
        check(playCanvas&&playCanvas.x>=-2&&playCanvas.y>=-2&&
          playCanvas.x+playCanvas.width<=t.width+2&&
          playCanvas.y+playCanvas.height<=t.height+2,
          'Responsive PLAYING canvas overflow: '+t.name);
        const playHud=physicalRect(playing.hud_rect,playCanvas,playing);
        const playHub=physicalRect(playing.hub_rect,playCanvas,playing);
        if(playCanvas.height>520)check(playHub.y+playHub.height<=playHud.y-3,
          'Responsive PLAYING HUB/HUD overlap: '+t.name);
        // GAME-076: verify ACTUALLY rendered Godot card and guide rectangles.
        // Only read debug telemetry; no command, angle, score or physics changes.
        if(t.name==='small-phone-landscape'){
          const panel=physicalRect(playing.info,playCanvas,playing);
          const card=physicalRect(playing.action_card_rect,playCanvas,playing);
          const guide=physicalRect(playing.help_guide_rect,playCanvas,playing);
          // Godot's viewport-to-CSS conversion yields e.g. 29.9999985px for a 30px chip.
          // Use a sub-pixel tolerance for the nominal-height check; never relax overlap clearance.
          const nominalHeightToleranceCss=0.01;
          check(card.width>0&&card.height+nominalHeightToleranceCss>=43&&
            guide.width>0&&guide.height+nominalHeightToleranceCss>=30,
            'Responsive action card or help guide missing: '+t.name+' '+JSON.stringify({card,guide}));
          const gapCss=guide.y-(card.y+card.height);
          check(gapCss>=4,
            'Responsive action card overlaps or touches help guide: '+t.name+' gap='+gapCss.toFixed(2));
          for(const [name,r] of [['card',card],['guide',guide]]){
            check(r.x>=panel.x-2&&r.y>=panel.y-2&&
              r.x+r.width<=panel.x+panel.width+2&&
              r.y+r.height<=panel.y+panel.height+2,
              'Responsive '+name+' exceeds info panel: '+t.name+' '+JSON.stringify({r,panel}));
          }
          proof.actionGuideSpacing={source:'GODOT_RENDERED_RECT_TELEMETRY_READ_ONLY',
            gapCssPx:Math.round(gapCss*100)/100,minimumCssPx:4,
            actionCard:card,helpGuide:guide,infoPanel:panel};
        }
        await page.screenshot({path:dir+'/'+t.name+'-layout-playing.png'});
        check(failures.length===0,'Responsive PLAYING browser errors: '+failures.join(' | '));
        proof.naturalStart={input:starter.input,physicalTapOrClick:true,
          state:playing.state,orbit:playing.orbit,energy:playing.energy,
          noQaCommand:true,noStateOverride:true};
        proof.playingGeometry={field:playing.field,info:playing.info};
        proof.evidenceScreenshots=[t.name+'-layout-intro.png',t.name+'-layout-playing.png'];
        // GAME-076: capture a LIVE last-3-seconds cargo warning on compact screens.
        // START is physical; only elapsed game time triggers the screenshot.
        // This read-only observer never changes score, timers, orbit, or physics.
        await page.waitForFunction(() => {
          const x=window.__P021_ORBIT;
          return x && x.state==='playing' && x.cargo_left<=2.95 &&
            x.cargo_left>=1.5 && x.energy===3 && x.deliveries===0;
        },null,{timeout:20000,polling:50});
        // Assert the real HUD draw path chose an urgent label, not merely that
        // the timer was <=3s. This is passive telemetry, not a QA state write.
        await page.waitForFunction(() => {
          const x=window.__P021_ORBIT;
          return x && /^0[123]s(?: LEFT!  HURRY  ·  [^…]+|! HURRY|!)$/.test(
            x.cargo_warning_rendered_text || '') && x.cargo_left>1.5;
        },null,{timeout:1250,polling:25});
        const compactWarningBefore=await snapshot(page);
        const compactWarningFile=t.name+'-cargo-warning-3s.png';
        await page.screenshot({path:dir+'/'+compactWarningFile});
        const compactWarningAfter=await snapshot(page);
        check(compactWarningBefore.state==='playing' &&
          compactWarningBefore.cargo_left>0 && compactWarningBefore.cargo_left<=3 &&
          compactWarningAfter.state==='playing' &&
          compactWarningAfter.cargo_left>0 && compactWarningAfter.cargo_left<=3 &&
          compactWarningAfter.energy===3 && compactWarningAfter.deliveries===0,
          'Compact warning capture missed natural 3s window: '+t.name+' '+
          JSON.stringify({before:compactWarningBefore.cargo_left,
            after:compactWarningAfter.cargo_left}));
        const selectedWarningTexts=[compactWarningBefore.cargo_warning_rendered_text,
          compactWarningAfter.cargo_warning_rendered_text];
        check(selectedWarningTexts.every(s=>typeof s==='string' &&
          /^0[123]s(?: LEFT!  HURRY  ·  [^…]+|! HURRY|!)$/.test(s)),
          'Compact warning HUD label not selected on actual draw: '+t.name+' '+
          JSON.stringify(selectedWarningTexts));
        proof.cargoWarning={result:'CAPTURED_UNREVIEWED',
          hudTextSelection:'PASS_UNCLIPPED_ACTUAL_DRAW_TEXT',
          methodDetail:'Godot _draw_fit_label returns the actually rendered string; no ellipsis allowed',
          renderedTexts:selectedWarningTexts,
          method:'natural clock after physical START',
          secondsBefore:compactWarningBefore.cargo_left,
          secondsAfter:compactWarningAfter.cargo_left,
          energy:compactWarningAfter.energy,deliveries:compactWarningAfter.deliveries,
          screenshot:compactWarningFile,
          visualWarningPass:'NOT VERIFIED - inspect PNG independently',
          physicalLegibility:'HUMAN GATE'};
        proof.evidenceScreenshots.push(compactWarningFile);
        proof.status='PASS_GEOMETRY';
      }catch(err){
        proof.failure=String(err.message||err);
        proof.browserErrors=failures;
      }finally{
        layoutSweep.push(proof);
        await context.close();
      }
    }
  }finally{await browser.close();}
  const output={task:'GAME-076',game:'GAME-G030',visualContract,
    method:'real touch/mouse STARTER/RUSH/NIGHT/ACE natural delivery and BEST persistence; read-only QA telemetry; no QA command/state override',
    screenshotStates:['intro','playing','route-rush','route-ace','miss-feedback','result','retry','sound-off','sound-on','replay','cue-stress','cargo-warning-3s'],
    physicalOutput:'NOT VERIFIED – must check actual device audio and first-time user experience',
    independentQualityScore:'NOT ASSESSED (manual visual/audio/human checks separate)',viewports:results,layoutSweep};
  fs.writeFileSync(dir+'/results.json',JSON.stringify(output,null,2));
  console.log(JSON.stringify(output,null,2));
  if(results.some(x=>x.status!=='PASS') || layoutSweep.some(x=>x.status!=='PASS_GEOMETRY'))process.exitCode=1;
}
run().catch(e=>{console.error(e);process.exitCode=1;});
