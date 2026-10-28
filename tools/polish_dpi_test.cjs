const {chromium}=require('playwright');
const fs=require('node:fs');
(async()=>{
 const b=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-unsafe-swiftshader']});
 const results=[];
 try {
  for(const dpr of [1,2]){
   const p=await b.newPage({viewport:{width:1152,height:648},deviceScaleFactor:dpr});
   const errors=[]; p.on('pageerror',e=>errors.push(e.message));
   p.on('console',m=>{if(m.type()==='error') errors.push(m.text());});
   await p.goto('http://127.0.0.1:8316/?v=polish3');
   await p.waitForFunction(()=>!document.querySelector('#status')||document.querySelector('#status')?.style.display==='none'||document.querySelector('#status')?.style.visibility==='hidden',{}, {timeout:60000});
   await p.waitForTimeout(600);
   const metrics=await p.evaluate(()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect();return {dpr:devicePixelRatio,css:[r.width,r.height],pixels:[c.width,c.height]};});
   if(metrics.pixels[0]!==Math.round(metrics.css[0]*dpr)||metrics.pixels[1]!==Math.round(metrics.css[1]*dpr)) errors.push('Canvas backing resolution mismatch');
   results.push({...metrics,errors}); await p.close();
  }
 }finally{await b.close();}
 fs.writeFileSync('tools/polish-dpi-check.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results));
 if(results.some(r=>r.errors.length)) process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
