// Serve a release build of tool/soak_app.dart with SKYWAY_SOAK=true, then run:
// SKYWAY_PLAYWRIGHT=/tmp/skyway-browser/node_modules/playwright node tool/soak_web.cjs
const {chromium}=require(process.env.SKYWAY_PLAYWRIGHT||'playwright');
const fs=require('node:fs');const path=require('node:path');
(async()=>{
 const output=process.env.SKYWAY_SOAK_OUTPUT||'build/soak';fs.mkdirSync(output,{recursive:true});
 const browser=await chromium.launch({executablePath:process.env.SKYWAY_CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist','--disable-background-timer-throttling','--disable-renderer-backgrounding']});
 try {
  const page=await browser.newPage({viewport:{width:430,height:900},deviceScaleFactor:1});
  const errors=[],samples=[];page.on('pageerror',error=>errors.push(String(error)));
  await page.goto(process.env.SKYWAY_URL||'http://127.0.0.1:8123');await page.waitForTimeout(10000);
  const session=await page.context().newCDPSession(page);await session.send('Performance.enable');
  for(let minute=0;minute<=30;minute++){
   if(minute)await page.waitForTimeout(60000);
   await session.send('HeapProfiler.collectGarbage');
   const {metrics}=await session.send('Performance.getMetrics');
   const sample={minute,...Object.fromEntries(metrics.filter(m=>['JSHeapUsedSize','Nodes','Documents','TaskDuration'].includes(m.name)).map(m=>[m.name,m.value]))};
   if(!(sample.JSHeapUsedSize>0))throw Error('Empty heap measurement');
   samples.push(sample);console.log(sample);
   fs.writeFileSync(path.join(output,'metrics.json'),JSON.stringify({samples,errors},null,2));
   if(minute%5===0)await page.screenshot({path:path.join(output,`minute-${minute}.png`)});
  }
  if(errors.length)throw Error(errors.join('\n'));
  console.log('Measurement complete. Review heap trend and screenshots before judging endurance.');
 } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
