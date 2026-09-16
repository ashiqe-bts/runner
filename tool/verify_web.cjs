// npm install --prefix /tmp/skyway-browser playwright
// SKYWAY_PLAYWRIGHT=/tmp/skyway-browser/node_modules/playwright node tool/verify_web.cjs
const {chromium}=require(process.env.SKYWAY_PLAYWRIGHT||'playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.SKYWAY_CHROME||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist']});
 try {
 const page=await browser.newPage({viewport:{width:430,height:900}});const errors=[];
 const upgradedAssets=new Set();
 page.on('response',response=>{
   if(response.ok() && response.url().includes('/flutter_scene_generated/')) upgradedAssets.add(response.url().split('/').pop());
 });
 page.on('pageerror',e=>errors.push(String(e)));
 await page.goto(process.env.SKYWAY_URL||'http://127.0.0.1:8124');
 await page.waitForTimeout(8000);await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 await page.getByRole('button',{name:'LET’S RUN'}).click();
 await page.waitForTimeout(500);
 const manifest=await (await page.request.get(new URL('assets/flutter_scene_generated/manifest.json',page.url()).href)).json();
 const entries=manifest.entries;
 for(const name of ['pip','officer','skyway']) {
   const asset=entries.find(entry=>entry.source===`assets/native_models/${name}.glb`);
   assert.ok(asset && upgradedAssets.has(asset.file), `Upgraded ${name} asset must load on web`);
 }
 if(process.env.SKYWAY_SCREENSHOT) await page.screenshot({path:process.env.SKYWAY_SCREENSHOT});
 for(const key of ['ArrowLeft','ArrowRight','ArrowUp','ArrowDown']){await page.keyboard.press(key);await page.waitForTimeout(1000);}
 await page.keyboard.press('KeyP');await page.waitForTimeout(200);
 await page.getByRole('button',{name:'Finish run & return home'}).click();
 for(const name of ['Couriers','Missions','Upgrades','Settings']){
   await page.getByRole('button',{name:`${name} ${name}`}).click();await page.waitForTimeout(150);
   await page.getByRole('button',{name:'Back',exact:true}).dispatchEvent('click');
 }
 const save=await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('skyway.progress.v1'))));
 assert.equal(save.tutorialCompleted,true);assert.ok(save.wallet>0);assert.ok(save.highScore>0);
 await page.reload();await page.waitForTimeout(6000);
 const restored=await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('skyway.progress.v1'))));assert.equal(restored.wallet,save.wallet);
 assert.deepEqual(errors,[]);console.log('PASS: upgraded courier/officer/world assets, tutorial, controls, pause, navigation, earned coins, save/reload, no page errors.');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
