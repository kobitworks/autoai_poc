const { chromium } = require('playwright');

const cases = [
  ['Phone Portrait',390,844],
  ['Phone Landscape',844,390],
  ['Tablet Portrait',768,1024],
  ['Tablet Landscape',1024,768],
];

(async()=>{
  const browser=await chromium.launch({headless:true});
  const results=[];
  let failed=false;
  for(const [name,width,height] of cases){
    const page=await browser.newPage({viewport:{width,height}});
    const errors=[];
    page.on('console',m=>{ if(m.type()==='error') errors.push('console:'+m.text()); });
    page.on('pageerror',e=>errors.push('page:'+e.message));
    try{
      await page.goto('http://127.0.0.1:8000/p021-game/games/number-sum/',{waitUntil:'domcontentloaded'});
      await page.selectOption('#topLevel','easy');
      await page.click('#btnStart');
      await page.waitForSelector('.grid',{state:'visible',timeout:30000});
      const board=await page.locator('.grid').boundingBox();
      const controls=await page.locator('.controlsRow').boundingBox();
      if(!board || !controls) throw new Error('board or controls missing');
      if(board.x < -1 || board.y < -1 || board.x+board.width > width+1 || board.y+board.height > height+1) throw new Error('board outside viewport');
      if(controls.x < -1 || controls.y < -1 || controls.x+controls.width > width+1 || controls.y+controls.height > height+1) throw new Error('controls outside viewport');
      await page.locator('.cell').first().click();
      await page.click('#modeEraser');
      await page.locator('.cell').nth(1).click();
      const opts=await page.locator('#topLevel option').allTextContents();
      if(!opts.some(x=>x.includes('Easy 5')) || !opts.some(x=>x.includes('Normal 6')) || !opts.some(x=>x.includes('Hard 7'))) throw new Error('difficulty options missing');
      if(errors.length) throw new Error(errors.join(' | '));
      results.push({name,width,height,pass:true,board,controls});
    }catch(e){
      failed=true; results.push({name,width,height,pass:false,error:String(e),errors});
    }finally{ await page.close(); }
  }
  await browser.close();
  console.log(JSON.stringify(results,null,2));
  if(failed) process.exit(1);
})();