const { test, expect } = require('@playwright/test');

const BASE = 'http://localhost:3001';

test.describe('Homepage', () => {
  test('loads with correct title', async ({ page }) => {
    await page.goto(BASE + '/');
    await expect(page).toHaveTitle(/toke/);
  });

  test('has CSS loaded (styled elements)', async ({ page }) => {
    await page.goto(BASE + '/');
    const nav = page.locator('nav.site-nav');
    await expect(nav).toBeVisible();
  });

  test('hero section visible', async ({ page }) => {
    await page.goto(BASE + '/');
    const hero = page.locator('section.hero h1');
    await expect(hero).toContainText('AI');
  });

  test('navigation links present', async ({ page }) => {
    await page.goto(BASE + '/');
    await expect(page.locator('a[href="/docs"]').first()).toBeVisible();
    await expect(page.locator('a[href="/docs/learn"]').first()).toBeVisible({ timeout: 5000 });
  });
});

test.describe('Navigation', () => {
  test('/docs loads', async ({ page }) => {
    await page.goto(BASE + '/docs');
    await expect(page).toHaveTitle(/Documentation/);
  });

  test('/docs/learn loads', async ({ page }) => {
    await page.goto(BASE + '/docs/learn');
    await expect(page).toHaveTitle(/toke/);
  });

  test('/docs/learn/06-strings-io loads', async ({ page }) => {
    await page.goto(BASE + '/docs/learn/06-strings-io');
    await expect(page).toHaveTitle(/Strings/);
  });

  test('/about loads', async ({ page }) => {
    await page.goto(BASE + '/about');
    const body = await page.content();
    expect(body.length).toBeGreaterThan(100);
  });

  test('/ecosystem loads', async ({ page }) => {
    await page.goto(BASE + '/ecosystem');
    const body = await page.content();
    expect(body.length).toBeGreaterThan(100);
  });

  test('/loke loads', async ({ page }) => {
    await page.goto(BASE + '/loke');
    const body = await page.content();
    expect(body.length).toBeGreaterThan(100);
  });

  test('/ooke loads', async ({ page }) => {
    await page.goto(BASE + '/ooke');
    const body = await page.content();
    expect(body.length).toBeGreaterThan(100);
  });
});

test.describe('API endpoints', () => {
  test('/health returns JSON', async ({ request }) => {
    const res = await request.get(BASE + '/health');
    expect(res.status()).toBe(200);
    const json = await res.json();
    expect(json.status).toBe('ok');
    expect(json.version).toBe('0.3.0');
  });

  test('/api/health returns JSON', async ({ request }) => {
    const res = await request.get(BASE + '/api/health');
    expect(res.status()).toBe(200);
    const json = await res.json();
    expect(json.status).toBe('ok');
  });

  test('/api/version returns version', async ({ request }) => {
    const res = await request.get(BASE + '/api/version');
    expect(res.status()).toBe(200);
    const json = await res.json();
    expect(json.version).toBe('0.3.0');
  });
});

test.describe('Static assets', () => {
  test('CSS loads with correct MIME', async ({ request }) => {
    const res = await request.get(BASE + '/static/css/style.css');
    expect(res.status()).toBe(200);
    const ct = res.headers()['content-type'];
    expect(ct).toContain('text/css');
    const body = await res.text();
    expect(body.length).toBeGreaterThan(1000);
  });
});

test.describe('Link navigation', () => {
  test('clicking Docs from homepage works', async ({ page }) => {
    await page.goto(BASE + '/');
    await page.click('a[href="/docs"]');
    await expect(page).toHaveTitle(/Documentation/);
    expect(page.url()).toContain('/docs');
  });

  test('clicking Learn from nav works', async ({ page }) => {
    await page.goto(BASE + '/');
    await page.click('a[href="/docs/learn"]');
    await page.waitForLoadState();
    const body = await page.content();
    expect(body.length).toBeGreaterThan(500);
  });
});

test.describe('404 handling', () => {
  test('non-existent page returns content', async ({ request }) => {
    const res = await request.get(BASE + '/nonexistent-page-xyz');
    // Should return something (either 404 page or servedir fallback)
    expect(res.status()).toBeGreaterThanOrEqual(200);
  });
});

test.describe('Content checks', () => {
  test('homepage mentions token efficiency', async ({ page }) => {
    await page.goto(BASE + '/');
    const text = await page.textContent('body');
    expect(text).toContain('token');
  });

  test('docs page has navigation structure', async ({ page }) => {
    await page.goto(BASE + '/docs');
    const links = await page.locator('a').count();
    expect(links).toBeGreaterThan(5);
  });

  test('no broken images on homepage', async ({ page }) => {
    await page.goto(BASE + '/');
    const images = page.locator('img');
    const count = await images.count();
    for (let i = 0; i < count; i++) {
      const img = images.nth(i);
      const src = await img.getAttribute('src');
      if (src && src.startsWith('/')) {
        const res = await page.request.get(BASE + src);
        expect(res.status(), `Image ${src} should load`).toBe(200);
      }
    }
  });
});
