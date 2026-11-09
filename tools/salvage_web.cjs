const puppeteer=require('puppeteer-core'),fs=require('node:fs'),assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await puppeteer.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-unsafe-swiftshader']});
 const errors=[],profiles=[];
 try{
  for(const profile of [{width:1152,height:648,cpu:1},{width:844,height:390,cpu:4}]){
   const page=await browser.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   await page.setViewport({width:profile.width,height:profile.height,isMobile:profile.cpu===4,hasTouch:profile.cpu===4});
   const cdp=await page.createCDPSession(),contexts=new Map();
   for(const event of ['WebAudio.contextCreated','WebAudio.contextChanged'])cdp.on(event,e=>contexts.set(e.context.contextId,e.context));
   await cdp.send('WebAudio.enable');await cdp.send('Emulation.setCPUThrottlingRate',{rate:profile.cpu});
   await page.goto('http://127.0.0.1:8318/?v=salvage-20261108&perf=1&stress=1&salvage=1&salvage_review=1&weapon=beam');
   await page.waitForFunction(()=>window.__noSurvivorSalvage?.panel===true,{timeout:120000});
   const tap=async key=>{
    const point=await page.evaluate(key=>{const state=window.__noSurvivorSalvage,canvas=document.querySelector('canvas').getBoundingClientRect(),p=key==='hardware'?state.buttons[0]:state.burst_button;const scale=Math.min(canvas.width/state.viewport[0],canvas.height/state.viewport[1]);return {x:canvas.left+(canvas.width-state.viewport[0]*scale)/2+p[0]*scale,y:canvas.top+(canvas.height-state.viewport[1]*scale)/2+p[1]*scale};},key);
    if(profile.cpu===4)await page.touchscreen.tap(point.x,point.y);else await page.mouse.click(point.x,point.y);
   };
   await page.screenshot({path:`screenshots/salvage-web-hardware-${profile.width}.png`});await tap('hardware');
   await page.waitForFunction(()=>window.__noSurvivorSalvage?.panel===false&&window.__noSurvivorSalvage.parts.includes('mines'),{timeout:15000});
   const before=await page.evaluate(()=>window.__noSurvivorSalvage.bursts);
   await page.waitForFunction(()=>window.__noSurvivorSalvage.energy>=100&&window.__noSurvivorSalvage.burst_left===0,{timeout:15000});await tap('burst');
   try{await page.waitForFunction(n=>window.__noSurvivorSalvage.bursts>n,{timeout:12000},before);}catch(e){await page.screenshot({path:'screenshots/salvage-web-input-failure.png'});console.log('INPUT_STATE',await page.evaluate(()=>({state:window.__noSurvivorSalvage})));throw e;}
   await delay(3000);const samples=[];
   for(let i=0;i<8;i++){await delay(1000);samples.push(await page.evaluate(()=>({perf:window.__noSurvivorPerf,salvage:window.__noSurvivorSalvage,beam:window.__noSurvivorWeapon})));}
   assert(samples.every(s=>s.salvage.rules.length===2&&s.salvage.elements[1]==='water'&&s.perf.fields<=4));
   const audio=[...contexts.values()].map(c=>({state:c.contextState,sampleRate:c.sampleRate}));assert(audio.some(c=>c.state==='running'));
   await page.screenshot({path:`screenshots/salvage-web-combat-${profile.width}.png`});profiles.push({...profile,audio,samples});await page.close();
  }
  fs.writeFileSync('build/salvage-web-report.json',JSON.stringify({errors,profiles,scope:'Synthetic invulnerable stress fixture, desktop GPU, emulated CPU/touch. Hardware and burst clicked through native canvas input; not physical phone or retention testing.'},null,2));assert.deepEqual(errors,[]);
  console.log(JSON.stringify({passed:true,errors,profiles:profiles.map(p=>({width:p.width,minFPS:Math.min(...p.samples.map(s=>s.perf.fps)),averageFPS:p.samples.reduce((n,s)=>n+s.perf.fps,0)/p.samples.length,parts:p.samples.at(-1).salvage.parts,bursts:p.samples.at(-1).salvage.bursts,audio:p.audio}))}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
