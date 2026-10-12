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
const dir = '/tmp/p021-g030-real-input';
const url = 'http://127.0.0.1:8000/p021-game/games/orbit-switch-courier/?qa=1';
function check(value, message) { if (!value) throw new Error(message); }
function fits(r,w,h) { return r && r.length===4 && r[0]>=-2 && r[1]>=-2 &&
  r[2]>100 && r[3]>70 && r[0]+r[2]<=w+2 && r[1]+r[3]<=h+2; }
async function snapshot(page) { return page.evaluate(() => window.__P021_ORBIT || null); }
async function until(page, predicate, stage, waitMs=16000, arg=null) {
  // GAME-076: poll narrow real-input windows on wall time rather than animation
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
  await input(page,t);
  await until(page,(a)=>{const x=window.__P021_ORBIT;return x&&x.orbit===a.to;},label+' transfer',3500,{to});
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
  fs.mkdirSync(dir,{recursive:true});
  const browser=await chromium.launch({headless:true});
  const results=[];
  try {
    for(const t of targets){
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
        // Orbit 1 angular velocity is negative. Wait for crossing at 4.50 radians.
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&x.state==='playing'&&
          x.orbit===1&&x.angle>=4.62&&x.angle<=4.68;},'approach natural switch');
        evidence.switchTrigger='4.62..4.68 rad, real-time observation';
        await input(page,t);
        evidence.switchAfter=await snapshot(page);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.orbit===0,'real orbit transfer',4000);
        d=await snapshot(page);
        check(d.energy===3,'Energy lost at switch');
        evidence.transfer={orbit:d.orbit,energy:d.energy};
        // Orbit 0 angular velocity is positive; Hub 0 is at 1.48 radians.
        // The actual scoring window is 1.33..1.63 (HUB_WINDOW=0.15).
        // Observe the middle 1.37..1.49 band, not a 0.05-rad sliver that
        // can be skipped when the browser or a tablet frame is delayed.
        // Delivery and full energy are still required: never force physics/state.
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&x.state==='playing'&&
          x.orbit===0&&x.cargo_target===0&&x.angle>=1.37&&x.angle<=1.49;},'approach natural delivery');
        evidence.hubTrigger='1.37..1.49 rad, real-time observation within natural HUB window';
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
        evidence.routeMoves.push(await physicalSwitch(page,t,0,1,4.37,4.45,'RUSH 0->1'));
        evidence.routeMoves.push(await physicalDeliver(page,t,1,3.53,3.68,2,'RUSH HUB1'));
        evidence.routeMoves.push(await physicalSwitch(page,t,1,2,2.55,2.63,'RUSH 1->2'));
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
            trace.push({ms:Math.round(performance.now()),orbit:x.orbit,
              angle:Math.round(x.angle*1000)/1000,cargo:x.cargo_target,
              cargoLeft:Math.round(x.cargo_left*100)/100,
              energy:x.energy,deliveries:x.deliveries});
            if (trace.length>320) trace.shift();
          },75);
        });
        evidence.routeMoves.push(await physicalDeliver(page,t,2,5.06,5.22,3,'NIGHT HUB2'));
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
        evidence.routeMoves.push(await physicalSwitch(page,t,2,1,5.60,5.69,'NIGHT 2->1'));
        evidence.routeMoves.push(await physicalSwitch(page,t,1,0,4.55,4.62,'NIGHT 1->0'));
        // GAME-076: Watch the full usable touch zone, not an easily skipped 0.16-rad sliver.
        // 1.28..1.68 stays inside the genuine ±0.23 HUB physics window.
        evidence.routeMoves.push(await physicalDeliver(page,t,0,1.28,1.68,4,'NIGHT HUB0'));
        evidence.routeMoves.push(await physicalSwitch(page,t,0,1,4.37,4.45,'NIGHT 0->1'));
        evidence.routeMoves.push(await physicalDeliver(page,t,1,3.53,3.68,5,'NIGHT HUB1'));
        evidence.routeMoves.push(await physicalSwitch(page,t,1,2,2.55,2.63,'NIGHT 1->2'));
        evidence.routeMoves.push(await physicalDeliver(page,t,2,5.06,5.22,6,'ACE HUB2'));
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
        check(errors.length===0,'Browser console/runtime errors: '+errors.join(' | '));
        // Stop the diagnostic observer before releasing this browser context.
        await page.evaluate(() => {
          if (window.__P021_NIGHT_TRACE_TIMER) clearInterval(window.__P021_NIGHT_TRACE_TIMER);
        });
        evidence.status='PASS';
      }catch(err){
        evidence.failure=err.message;
        evidence.browserErrors=errors;
        if (/NIGHT HUB0/.test(evidence.failure)) {
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
        results.push(evidence);
        await context.close();
      }
    }
  }finally{await browser.close();}
  const output={task:'GAME-076',game:'GAME-G030',
    method:'real touch/mouse STARTER/RUSH/NIGHT/ACE natural delivery and BEST persistence; read-only QA telemetry; no QA command/state override',
    screenshotStates:['intro','playing','route-rush','route-ace','miss-feedback','result','retry','sound-off','sound-on','replay'],
    physicalOutput:'NOT VERIFIED – must check actual device audio and first-time user experience',
    independentQualityScore:'NOT ASSESSED (manual visual/audio/human checks separate)',viewports:results};
  fs.writeFileSync(dir+'/results.json',JSON.stringify(output,null,2));
  console.log(JSON.stringify(output,null,2));
  if(results.some(x=>x.status!=='PASS'))process.exitCode=1;
}
run().catch(e=>{console.error(e);process.exitCode=1;});
