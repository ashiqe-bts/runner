// Serve the release build on :8124. Install Playwright outside the repository.
// SKYWAY_PLAYWRIGHT=/tmp/skyway-browser/node_modules/playwright node tool/review_mobile_ui.cjs
const {chromium} = require(process.env.SKYWAY_PLAYWRIGHT || 'playwright');
const {mkdirSync} = require('node:fs');
const assert = require('node:assert/strict');

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.SKYWAY_CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: ['--enable-webgl', '--ignore-gpu-blocklist'],
  });
  const output = 'docs/screenshots/mobile-ui';
  mkdirSync(output, {recursive: true});
  try {
    const page = await browser.newPage({viewport: {width: 390, height: 844}});
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    await page.goto(process.env.SKYWAY_URL || 'http://127.0.0.1:8124');
    await page.waitForTimeout(8000);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.getByRole('button', {name: 'PLAY', exact: true}).waitFor();
    for (const [width, height] of [[320,568], [360,780], [390,844], [430,932], [1024,768]]) {
      await page.setViewportSize({width, height});
      await page.waitForTimeout(300);
      await page.screenshot({path: `${output}/home-${width}.png`});
    }
    await page.setViewportSize({width: 390, height: 844});
    await page.getByRole('button', {name: 'Next courier', exact: true}).click();
    await page.getByRole('button', {name: 'Couriers', exact: true}).click();
    await page.getByRole('button', {name: 'UNLOCK • 1000 COINS', exact: true}).waitFor();
    assert.equal(await page.getByRole('button', {name: 'UNLOCK • 1000 COINS', exact: true}).isDisabled(), true);
    await page.screenshot({path: `${output}/couriers.png`});
    await page.getByRole('button', {name: 'Back', exact: true}).dispatchEvent('click');
    for (const label of ['Missions', 'Upgrades', 'Settings']) {
      await page.getByRole('button', {name: label, exact: true}).click();
      await page.waitForTimeout(150);
      await page.screenshot({path: `${output}/${label.toLowerCase()}.png`});
      await page.getByRole('button', {name: 'Back', exact: true}).dispatchEvent('click');
    }
    await page.getByRole('button', {name: 'PLAY', exact: true}).click();
    await page.waitForTimeout(300);
    await page.screenshot({path: `${output}/tutorial.png`});
    for (const key of ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown']) {
      await page.keyboard.press(key);
      await page.waitForTimeout(1000);
    }
    await page.screenshot({path: `${output}/gameplay.png`});
    await page.getByRole('button', {name: 'Pause', exact: true}).click();
    await page.waitForTimeout(150);
    await page.screenshot({path: `${output}/pause.png`});
    await page.getByRole('button', {name: 'KEEP RUNNING', exact: true}).click();
    assert.deepEqual(errors, []);
    console.log('PASS: responsive lobby, locked preview, secondary menus, tutorial, gameplay and pause. Screenshots:', output);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
