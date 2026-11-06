const puppeteer=require('puppeteer-core'),fs=require('node:fs'),assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const browser=await puppeteer.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-unsafe-swiftshader']});
 const errors=[],profiles=[];
 try{
  for(const profile of [{width:1152,height:648,cpu:1},{width:844,height:390,cpu:4}]){
   const page=await browser.newPage(),contexts=new Map();
   page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   await page.setViewport({...profile,isMobile:profile.cpu===4,hasTouch:profile.cpu===4});
   const cdp=await page.createCDPSession();
   for(const event of ['WebAudio.contextCreated','WebAudio.contextChanged']) cdp.on(event,e=>contexts.set(e.context.contextId,e.context));
   await cdp.send('WebAudio.enable');await cdp.send('Emulation.setCPUThrottlingRate',{rate:profile.cpu});
   await page.goto('http://127.0.0.1:8318/?v=flight-pulse&perf=1&stress=1&weapon=beam');
   await page.waitForFunction(()=>window.__noSurvivorWeapon?.weapon==='beam',{timeout:120000});
   await page.mouse.click(100,125);await delay(2000);
   const samples=[];
   for(let i=0;i<10;i++){await delay(1000);samples.push(await page.evaluate(()=>({perf:window.__noSurvivorPerf,beam:window.__noSurvivorWeapon})));}
   assert(samples.every(s=>s.beam.weapon==='beam'&&s.beam.beam_length>0));
   assert(samples.at(-1).beam.audio_cycles>3);
   const audio=[...contexts.values()].map(c=>({state:c.contextState,sampleRate:c.sampleRate}));
   assert(audio.some(c=>c.state==='running'),'WebAudio must run after a user gesture');
   await page.screenshot({path:`screenshots/flight-pulse-web-${profile.width}.png`});
   profiles.push({...profile,audio,samples});await page.close();
  }
  fs.writeFileSync('build/flight-pulse-web-report.json',JSON.stringify({errors,profiles,scope:'Desktop GPU, synthetic stress scene and emulated CPU/touch; not a physical phone or human audio mix review.'},null,2));
  assert.deepEqual(errors,[]);
  console.log(JSON.stringify({passed:true,errors,profiles:profiles.map(p=>({width:p.width,audio:p.audio,minFPS:Math.min(...p.samples.map(s=>s.perf.fps)),averageFPS:p.samples.reduce((n,s)=>n+s.perf.fps,0)/p.samples.length,cycles:p.samples.at(-1).beam.audio_cycles}))}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
