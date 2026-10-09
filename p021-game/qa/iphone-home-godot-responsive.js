/* GAME-G016: browser smoke / responsive / rendered-pixels checks for Godot iPhone PWA. */
const fs=require('fs');
const path=require('path');
const {chromium}=require('playwright');
const {PNG}=require('pngjs');

const URL='http://127.0.0.1:8765/p021-game/games/iphone-home/';
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
   report.push({view:view.name,colors:colors.size,stat,errors});
   console.log('PASS',view.name,JSON.stringify({colors:colors.size,canvas:stat.canvas,manifest:stat.manifest,errors}));
   await context.close();
  }
 } finally {
  await browser.close();
  fs.writeFileSync(path.join(OUTPUT,'result.json'),JSON.stringify({source:'Godot 4.7.2',checks:report},null,2)+'\n');
 }
}
main().catch(e=>{console.error(e.stack||String(e));process.exit(1);});
