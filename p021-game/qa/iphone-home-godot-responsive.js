/* GAME-G016: browser smoke / responsive / rendered-pixels checks for Godot iPhone PWA. */
const fs=require('fs');
const path=require('path');
const {chromium}=require('playwright');
const {PNG}=require('pngjs');

const URL='http://127.0.0.1:8765/p021-game/games/iphone-home/';
const TARGET='https://kobitworks.github.io/autoai_poc/p021-game/games/iphone-home/';
const OUTPUT=path.resolve('p021-game/docs/qa/iphone-home-godot');
const VIEWS=[
 {name:'iphone-390x844',width:390,height:844,mobile:true},
 {name:'iphone-430x932',width:430,height:932,mobile:true},
 {name:'ipad-768x1024',width:768,height:1024,mobile:true},
 {name:'landscape-844x390',width:844,height:390,mobile:true},
];

async function main(){
 fs.mkdirSync(OUTPUT,{recursive:true});
 const browser=await chromium.launch({headless:true,args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader']});
 const report=[];
 try{
  for(const view of VIEWS){
   const context=await browser.newContext({
    viewport:{width:view.width,height:view.height},
    deviceScaleFactor:1,isMobile:view.mobile,hasTouch:true,
    reducedMotion:'reduce'
   });
   const page=await context.newPage();
   const errors=[];
   page.on('pageerror',err=>errors.push(err.message));
   page.on('console',msg=>{if(msg.type()==='error')errors.push('console: '+msg.text());});
   const response=await page.goto(URL,{waitUntil:'domcontentloaded',timeout:40000});
   if(!response||response.status()!==200)throw new Error(view.name+' returned '+(response&&response.status()));
   await page.waitForFunction(()=>{
    const c=document.querySelector('canvas');
    return c&&c.width>200&&c.height>150;
   },null,{timeout:40000});
   await page.waitForTimeout(6000);
   const buffer=await page.screenshot({path:path.join(OUTPUT,view.name+'.png')});
   const png=PNG.sync.read(buffer);
   const colors=new Set();
   for(let y=5;y<png.height;y+=Math.max(5,Math.floor(png.height/38))){
    for(let x=5;x<png.width;x+=Math.max(5,Math.floor(png.width/20))){
     const i=(y*png.width+x)*4;
     colors.add([png.data[i]>>4,png.data[i+1]>>4,png.data[i+2]>>4].join(':'));
    }
   }
   if(colors.size<25)throw new Error(view.name+': screen may be blank, '+colors.size+' colors');
   if(errors.some(x=>/SCRIPT ERROR|Parse Error|Uncaught|wasm.*abort/i.test(x)))throw new Error(view.name+': runtime errors: '+errors.join('; '));
   const stat=await page.evaluate(()=>({
     title:document.title,
     canvas:[document.querySelector('canvas')?.width,document.querySelector('canvas')?.height],
     manifest:!!document.querySelector('link[rel=manifest]'),
     hasIcon:!!document.querySelector('link[rel*=icon]')
   }));
   // Swipe to home page 2, select the Icons8 QR tile, and check the QR sheet.
   const landscape=view.width>view.height*1.42&&view.height<620;
   // The iPhone home screen remains portrait on a landscape browser viewport.
   // Godot letterboxes its 390x844 content horizontally, as on an iPhone preview.
   const z=Math.min(view.width/390,view.height/844);
   const ox=(view.width-390*z)/2;
   const oy=(view.height-844*z)/2;
   const xy=(x,y)=>({x:Math.round(ox+x*z),y:Math.round(oy+y*z)});
   const start=xy(317,380);
   const end=xy(65,380);
   await page.mouse.move(start.x,start.y);
   await page.mouse.down();
   await page.mouse.move(end.x,end.y,{steps:10});
   await page.mouse.up();
   await page.waitForTimeout(550);
   const beforeQR=PNG.sync.read(await page.screenshot({path:path.join(OUTPUT,view.name+'-page2.png')}));
   const icon=xy(53,465);
   await page.mouse.click(icon.x,icon.y);
   await page.waitForTimeout(400);
   const withQR=PNG.sync.read(await page.screenshot({path:path.join(OUTPUT,view.name+'-qr-open.png')}));
   let changed=0,seen=0;
   for(let i=0;i<beforeQR.data.length;i+=16){
    const dr=Math.abs(beforeQR.data[i]-withQR.data[i]);
    const dg=Math.abs(beforeQR.data[i+1]-withQR.data[i+1]);
    const db=Math.abs(beforeQR.data[i+2]-withQR.data[i+2]);
    seen++;
    if(dr+dg+db>95)changed++;
   }
   const ratio=changed/seen;
   if(ratio<(landscape?0.025:0.15))throw Error(view.name+': QR dialog did not render, changed-pixel ratio '+ratio.toFixed(3));
   const close=xy(195,635);
   await page.mouse.click(close.x,close.y);
   await page.waitForTimeout(240);
   const closed=PNG.sync.read(await page.screenshot());
   let remaining=0;
   for(let i=0;i<closed.data.length;i+=16){
    if(Math.abs(closed.data[i]-beforeQR.data[i])+Math.abs(closed.data[i+1]-beforeQR.data[i+1])+Math.abs(closed.data[i+2]-beforeQR.data[i+2])>95)remaining++;
   }
   if(remaining/seen>0.06)throw Error(view.name+': QR dialog failed to close cleanly');
   report.push({view:view.name,colors:colors.size,qrDialogPixelChange:Number(ratio.toFixed(3)),stat,errors});
   console.log('PASS',view.name,JSON.stringify({colors:colors.size,canvas:stat.canvas,manifest:stat.manifest,errors}));
   await context.close();
  }
  // The portal must offer a working QR button even when Godot hasn't loaded.
  const hub=await browser.newPage();
  try {
   await hub.goto('http://127.0.0.1:8765/p021-game/',{waitUntil:'domcontentloaded'});
   await hub.locator('#game016QrButton').click();
   await hub.locator('#game016QrDialog[open]').waitFor();
   const qrSrc=await hub.locator('#game016QrDialog img').evaluate(async img=>{
    if(!img.complete)await new Promise((ok,fail)=>{img.onload=ok;img.onerror=fail;});
    if(img.naturalWidth<128||img.naturalHeight<128)throw Error('QR image missing');
    return new URL(img.getAttribute('src'),location.href).pathname;
   });
   if(!qrSrc.endsWith('/p021-game/games/iphone-home/site-qr.png'))throw Error('Unexpected QR target image: '+qrSrc);
   await hub.locator('#game016QrClose').click();
   if(await hub.locator('#game016QrDialog').evaluate(x=>x.open))throw Error('Portal QR dialog stayed open');
   report.push({portalQR:'passed',qrImage:qrSrc,target:TARGET});
   console.log('PASS portal QR dialog',TARGET);
  }finally{await hub.close();}
 } finally {
  await browser.close();
  fs.writeFileSync(path.join(OUTPUT,'result.json'),JSON.stringify({source:'Godot 4.7.2',checks:report},null,2)+'\n');
 }
}
main().catch(e=>{console.error(e.stack||String(e));process.exit(1);});
