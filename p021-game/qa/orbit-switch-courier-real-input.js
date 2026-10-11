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
async function until(page, predicate, stage, waitMs=16000) {
  await page.waitForFunction(predicate,null,{timeout:waitMs,polling:'raf'})
    .catch(e=>{throw new Error(stage+': '+e.message);});
}
async function input(page,t) {
  // Use the once-calculated physical pointer position: no DOM queries on the timing-critical path.
  check(t.hitPoint,'Hit point was not prepared');
  if(t.input==='touch') await page.touchscreen.tap(t.hitPoint.x,t.hitPoint.y);
  else await page.mouse.click(t.hitPoint.x,t.hitPoint.y);
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
        // Cache coordinates only once before starting gameplay; telemetry may update continuously.
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
        check(d.orbit===1 && d.cargo_target===0 && d.energy===3,'Unexpected deterministic round or double start input');
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
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&x.state==='playing'&&
          x.orbit===0&&x.angle>=1.345&&x.angle<=1.395;},'approach natural delivery');
        evidence.hubTrigger='1.345..1.395 rad, real-time observation';
        await input(page,t);
        evidence.hubAfter=await snapshot(page);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.deliveries>=1,'real delivery',4000);
        d=await snapshot(page);
        check(d.deliveries===1&&d.score>0&&d.energy===3,'Natural score/delivery missing');
        evidence.delivery={deliveries:d.deliveries,score:d.score,energy:d.energy};
        // Three real misses at 2.0 rad: no nearby active transfer/HUB window.
        await until(page,()=>{const x=window.__P021_ORBIT;return x&&x.state==='playing'&&
          x.orbit===0&&x.angle>=2.00&&x.angle<=2.13;},'safe miss zone');
        for(let energy=2;energy>=0;energy--){
          await page.waitForTimeout(170);
          await input(page,t);
          await page.waitForFunction(n=>window.__P021_ORBIT && window.__P021_ORBIT.energy===n,
            energy,{timeout:7000,polling:'raf'});
        }
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.state==='result','RESULT');
        d=await snapshot(page);
        const score=d.score;
        check(score>0&&d.best>=score,'RESULT score/BEST invalid');
        evidence.result={score,best:d.best,energy:d.energy};
        await page.screenshot({path:dir+'/'+t.name+'-result.png'});
        // Retry is a separate human action, not the browser's duplicate pointer event.
        await page.waitForTimeout(170);
        await input(page,t);
        await until(page,()=>window.__P021_ORBIT && window.__P021_ORBIT.state==='intro','RETRY');
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
        evidence.status='PASS';
      }catch(err){
        evidence.failure=err.message;
        evidence.browserErrors=errors;
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
  const output={task:'GAME-071',game:'GAME-G030',
    method:'real touch/mouse events on live orbital physics; read-only QA telemetry',
    independentQualityScore:'NOT ASSESSED (visual/audio/human checks separate)',viewports:results};
  fs.writeFileSync(dir+'/results.json',JSON.stringify(output,null,2));
  console.log(JSON.stringify(output,null,2));
  if(results.some(x=>x.status!=='PASS'))process.exitCode=1;
}
run().catch(e=>{console.error(e);process.exitCode=1;});
