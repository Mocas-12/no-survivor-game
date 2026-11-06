const puppeteer = require('puppeteer-core');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
  const browser = await puppeteer.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-unsafe-swiftshader']});
  const errors = [], results = [];
  try {
    const page = await browser.newPage();
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => {if(m.type()==='error') errors.push(m.text());});
    await page.setViewport({width:1152,height:648});
    await page.goto('http://127.0.0.1:8318/?v=full-plan-2');
    await page.waitForFunction(() => !document.querySelector('#status'), {timeout:90000});
    await delay(1000);
    await page.mouse.click(500,567);
    await page.mouse.click(210,497);
    await delay(21000);
    await page.screenshot({path:'screenshots/full-plan-web-draft.png'});
    await page.goto('http://127.0.0.1:8318/?v=full-plan-2&perf=1&stress=1');
    await page.waitForFunction(() => window.__noSurvivorPerf?.fps>0, {timeout:90000});
    const gpu = await page.evaluate(() => {
      const gl = document.querySelector('canvas')?.getContext('webgl2');
      const ext = gl?.getExtension('WEBGL_debug_renderer_info');
      return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : 'unavailable';
    });
    const cdp = await page.createCDPSession();
    for (const profile of [{width:1152,height:648,cpu:1},{width:844,height:390,cpu:4}]) {
      await page.setViewport({width:profile.width,height:profile.height,isMobile:profile.cpu===4,hasTouch:profile.cpu===4});
      await cdp.send('Emulation.setCPUThrottlingRate',{rate:profile.cpu});
      await page.waitForFunction(() => window.__noSurvivorPerf?.fps>0, {timeout:90000});
      await delay(2000);
      const samples=[];
      for(let i=0;i<10;i++){await delay(1000);samples.push(await page.evaluate(()=>window.__noSurvivorPerf));}
      await page.screenshot({path:`screenshots/full-plan-stress-${profile.width}.png`});
      results.push({...profile,gpu,samples,scope:'Labelled synthetic invulnerable stress scene. Mobile viewport and CPU throttling on desktop; not physical phone performance.'});
    }
    fs.writeFileSync('build/full-plan-web-report.json',JSON.stringify({errors,results},null,2));
    assert.deepEqual(errors,[]);
    console.log(JSON.stringify({passed:true,errors,profiles:results.map(r=>({width:r.width,cpu:r.cpu,minFPS:Math.min(...r.samples.map(s=>s.fps)),averageFPS:r.samples.reduce((n,s)=>n+s.fps,0)/r.samples.length,peakMobs:Math.max(...r.samples.map(s=>s.mobs))}))}));
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
