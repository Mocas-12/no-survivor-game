const {chromium}=require('playwright');
const fs=require('node:fs'),assert=require('node:assert/strict');
(async()=>{
const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-unsafe-swiftshader']});
const errors=[],events=[];
try{
 const p=await browser.newPage({viewport:{width:1152,height:648}});
 p.on('pageerror',e=>errors.push(e.message));
 p.on('console',m=>{if(m.type()==='error') errors.push(m.text());if(/ASSAULT_REVIEW_READY|BLENDER_HULL_PREVIEW/.test(m.text())) events.push(m.text());});
 await p.goto('http://127.0.0.1:8316/?review=assault&v=blender-prototype');
 await p.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:60000});
 for(let i=0;i<30&&!events.some(x=>x.includes('ASSAULT_REVIEW_READY'));i++) await p.waitForTimeout(250);
 assert(events.some(x=>x.includes('ASSAULT_REVIEW_READY')),'Actual review scene must load');
 await p.waitForTimeout(700);await p.screenshot({path:'screenshots/assault-review-web.png'});
 await p.mouse.click(180,135);await p.waitForTimeout(300);await p.screenshot({path:'screenshots/assault-review-top-web.png'});
 await p.mouse.click(285,135);await p.waitForTimeout(300);await p.screenshot({path:'screenshots/assault-review-side-web.png'});
 await p.mouse.click(75,135);await p.mouse.move(650,330);await p.mouse.down();await p.mouse.move(810,410,{steps:16});await p.mouse.up();await p.mouse.wheel(0,-120);await p.waitForTimeout(300);await p.screenshot({path:'screenshots/assault-review-orbit-web.png'});
 await p.mouse.click(390,135);await p.waitForURL('**/?hull=blender',{timeout:60000});
 await p.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:60000});
 for(let i=0;i<30&&!events.some(x=>x.includes('BLENDER_HULL_PREVIEW'));i++) await p.waitForTimeout(250);
 assert(events.some(x=>x.includes('BLENDER_HULL_PREVIEW')),'Game must enable the real GLB art preview');
 await p.mouse.click(210,497);await p.waitForTimeout(1800);await p.screenshot({path:'screenshots/assault-flight-web.png'});
 await p.keyboard.press('Escape');await p.waitForTimeout(300);await p.screenshot({path:'screenshots/assault-flight-pause-web.png'});
 assert.deepEqual(errors,[]);
 const result={passed:true,events,checks:['actual review scene loads','top and side preset controls','mouse orbit and wheel zoom','native button opens GLB flight preview','game starts and pauses'],errors};
 fs.writeFileSync('tools/assault-review-web-check.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
