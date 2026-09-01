// Real end-to-end smoke test: logs into the live site with a dedicated
// test account and confirms the dashboard actually renders. Catches the
// class of bug a Supabase ping can't - JS syntax errors, unhandled promise
// rejections, runtime crashes after login - by running the real page in a
// real browser, the same way a client would hit it.
'use strict';
const { chromium } = require('playwright');

const SITE = process.env.HEALTHCHECK_SITE || 'https://form-ai.io';
const EMAIL = process.env.HEALTHCHECK_EMAIL;
const PASSWORD = process.env.HEALTHCHECK_PASSWORD;

if (!EMAIL || !PASSWORD) {
  console.error('Missing HEALTHCHECK_EMAIL / HEALTHCHECK_PASSWORD env vars.');
  process.exit(1);
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  // Only uncaught JS exceptions count as a failure signal. console.error()
  // also fires for harmless things (a missing favicon, an optional font
  // 404, a third-party script) that don't mean the app is broken - checked
  // this against a real passing run before locking it down to pageerror only.
  const pageErrors = [];
  page.on('pageerror', (err) => pageErrors.push(err.message));

  let failure = null;

  try {
    await page.goto(`${SITE}/login.html`, { waitUntil: 'networkidle', timeout: 30000 });

    await page.fill('#siEmail', EMAIL);
    await page.fill('#siPass', PASSWORD);
    await page.click('#siBtn');

    // login.html redirects to dashboard-new.html on success
    await page.waitForURL('**/dashboard-new.html', { timeout: 20000 });

    // dashboard-new.html removes #page-loader once it finishes rendering
    await page.waitForSelector('#page-loader', { state: 'detached', timeout: 20000 });

    // sanity: the app actually mounted something into #root
    const rootChildren = await page.$eval('#root', (el) => el.children.length);
    if (rootChildren === 0) {
      failure = 'Dashboard #root is empty after loader removal - app did not mount.';
    }
  } catch (e) {
    failure = `Flow did not complete: ${e.message}`;
  }

  if (!failure && pageErrors.length) {
    failure = `Uncaught JS error(s) during login/dashboard flow:\n${pageErrors.join('\n')}`;
  }

  if (failure) {
    console.error('::error::' + failure);
    try {
      await page.screenshot({ path: 'healthcheck-failure.png', fullPage: true });
      console.log('Saved screenshot: healthcheck-failure.png');
    } catch (_) {}
    await browser.close();
    process.exit(1);
  }

  console.log('OK: login -> dashboard render verified, no JS errors.');
  await browser.close();
})();
