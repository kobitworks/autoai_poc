const { chromium } = require('playwright');
const cases=[['Phone Portrait',390,844],['Phone Landscape',844,390],['Tablet Portrait',768,1024],['Tablet Landscape',1024,768]];
(async()=>{const browser=await chromium.launch({headless:true});let failed=false;const results=[];
for(const[name,width,height]of cases){const page=await browser.newPage({viewport:{width,height}}),errors=[];page.on('console',m=>{if(m.type()==='error')errors.push('console:'+m.text())});page.on('pageerror',e=>errors.push('page:'+e.message));
try{await page.goto('http://127.0.0.1:8000/p021-game/games/flash-mental-math/?qa=1',{waitUntil:'domcontentloaded'});
if(await page.locator('#stageSelect option').count()!==5)throw new Error('stage options != 5');
if(await page.locator('#levelSelect option').count()!==5)throw new Error('level options != 5');
if(await page.locator('#roundSelect option').count()!==10)throw new Error('round options != 10');
await page.selectOption('#stageSelect','5');await page.selectOption('#levelSelect','5');await page.selectOption('#roundSelect','1');
const top=await page.locator('.topCard').boundingBox();if(!top||top.x<-1||top.x+top.width>width+1)throw new Error('top outside viewport');
await page.click('#btnStart');await page.waitForSelector('#keypadCard:not(.is-hidden)',{timeout:5000});
await page.click('[data-key="1"]');if((await page.locator('#answerDisplay').textContent())!=='1')throw new Error('keypad input failed');
await page.click('[data-key="clear"]');await page.click('[data-key="0"]');await page.click('[data-key="ok"]');
await page.waitForSelector('[data-result="true"]',{timeout:3000});
const game=await page.locator('#arena').boundingBox();if(!game||game.x<-1||game.x+game.width>width+1)throw new Error('arena outside viewport');
if(errors.length)throw new Error(errors.join(' | '));results.push({name,width,height,pass:true});}catch(e){failed=true;results.push({name,width,height,pass:false,error:String(e),errors});}finally{await page.close();}}
await browser.close();console.log(JSON.stringify(results,null,2));if(failed)process.exit(1);})();