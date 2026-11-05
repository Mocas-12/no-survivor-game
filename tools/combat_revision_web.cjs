const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-unsafe-swiftshader']});
 const errors=[],events=[];
 try {
  const p=await browser.newPage({viewport:{width:1152,height:648}});
  p.on('pageerror',e=>errors.push(e.message));
  p.on('console',m=>{if(m.type()==='error')errors.push(m.text());if(/FLEET_|HOSTILE_|BOSS_PHASE_/.test(m.text()))events.push(m.text());});
  await p.goto('http://127.0.0.1:8316/?review=fleet&v=combat-rework');
  await p.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:60000});
  await p.waitForTimeout(900);
  assert(events.some(s=>s.includes('FLEET_REVIEW_READY')));
  await p.mouse.click(341,615);
  for(let id=1;id<=6;id++){
   await p.mouse.click(260,247);await p.keyboard.press('Home');await p.waitForTimeout(150);
   for(let i=1;i<id;i++){await p.keyboard.press('ArrowRight');await p.waitForTimeout(150);}
   for(let phase=1;phase<=(id===6?3:2);phase++){
    await p.mouse.click([70,175,310][phase-1],337);await p.waitForTimeout(150);
    assert(events.some(s=>s.trim()===`BOSS_PHASE_VIEW ${id} ${phase}`),`Missing boss ${id} phase ${phase}`);
   }
  }
  await p.screenshot({path:'screenshots/combat-web-omega-p3.png'});
  await p.mouse.click(456,615);
  await p.mouse.click(260,247);await p.keyboard.press('Home');
  for(let i=0;i<6;i++){
   if(i)await p.keyboard.press('ArrowRight');await p.waitForTimeout(950);
   assert(events.some(s=>s.trim()===`HOSTILE_VIEW 3 ${i}`));
  }
  await p.screenshot({path:'screenshots/combat-web-reaction-lab.png'});
  await p.mouse.click(427,155);await p.waitForURL('**/?v=combat-rework');
  await p.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:60000});
  await p.waitForTimeout(900);await p.mouse.click(210,497);await p.waitForTimeout(6000);
  await p.screenshot({path:'screenshots/combat-web-gameplay.png'});
  await p.keyboard.press('Escape');await p.waitForTimeout(300);
  await p.screenshot({path:'screenshots/combat-web-pause.png'});
  assert.deepEqual(errors,[]);
  const result={passed:true,bossPhases:13,reactionPreviews:6,checks:['Actual exported WebGL model viewer','All six P1/P2 hulls and OMEGA P3','Reaction geometry playback','Native game start, six seconds of gameplay and pause'],errors};
  fs.writeFileSync('tools/combat-revision-web-check.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
