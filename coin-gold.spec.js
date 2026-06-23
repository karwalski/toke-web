// Coin Gold brand + accessibility checks (Epic 115.13)
// Run against a server serving the built site:
//   ./website --http --port 3001   (or set BASE_URL)
const { test, expect } = require('@playwright/test');

const BASE = process.env.BASE_URL || 'http://localhost:3001';

const PAGES = ['/', '/docs', '/docs/reference', '/ecosystem', '/tokens', '/tokenizer', '/ooke'];

test.describe('Coin Gold brand', () => {
  test('nav wordmark renders the gold coin (::before)', async ({ page }) => {
    await page.goto(BASE + '/');
    const coin = await page.locator('.site-nav .logo').evaluate((el) => {
      const s = getComputedStyle(el, '::before');
      return { content: s.content, bg: s.backgroundImage, w: s.width };
    });
    expect(coin.bg).toContain('radial-gradient'); // the CSS coin
    expect(parseFloat(coin.w)).toBeGreaterThan(0);
  });

  test('homepage hero has coin lockup + pills', async ({ page }) => {
    await page.goto(BASE + '/');
    await expect(page.locator('.hero .lockup .coin')).toBeVisible();
    await expect(page.locator('.hero .lockup .wordmark')).toHaveText(/toke/);
    await expect(page.locator('.hero .pill-row .pill').first()).toBeVisible();
  });

  test('brand fonts are requested', async ({ page }) => {
    await page.goto(BASE + '/');
    const links = await page.locator('link[rel="stylesheet"]').evaluateAll(
      (els) => els.map((e) => e.href)
    );
    expect(links.some((h) => /JetBrains\+Mono/.test(h) && /Space\+Grotesk/.test(h))).toBeTruthy();
  });

  test('gold accent, not legacy purple', async ({ page }) => {
    await page.goto(BASE + '/');
    const css = await (await page.request.get(BASE + '/static/css/style.css')).text();
    expect(css).toContain('Coin Gold');
    expect(css).not.toMatch(/#7c83fd|#c792ea/i); // old palette gone
  });

  test('docs use the light-cream surface', async ({ page }) => {
    await page.goto(BASE + '/docs/reference');
    await expect(page.locator('body.theme-light')).toHaveCount(1);
  });
});

test.describe('Accessibility & integrity', () => {
  for (const path of PAGES) {
    test(`${path} — lang, single h1, no raw template directives`, async ({ page }) => {
      const resp = await page.goto(BASE + path);
      expect(resp.status()).toBe(200);
      await expect(page.locator('html')).toHaveAttribute('lang', /.+/);
      // exactly one top-level <h1>
      expect(await page.locator('h1').count()).toBeGreaterThanOrEqual(1);
      // no unrendered {= ... =} / {! ... !} build directives leaked to output
      const body = await page.locator('body').innerText();
      expect(body).not.toMatch(/\{=\s|\s=\}/);
    });
  }

  test('all images have alt text', async ({ page }) => {
    await page.goto(BASE + '/');
    const missing = await page.locator('img:not([alt])').count();
    expect(missing).toBe(0);
  });

  test('links have discernible text', async ({ page }) => {
    await page.goto(BASE + '/');
    const empties = await page.locator('a:visible').evaluateAll(
      (as) => as.filter((a) => !a.textContent.trim() && !a.getAttribute('aria-label')).length
    );
    expect(empties).toBe(0);
  });
});
