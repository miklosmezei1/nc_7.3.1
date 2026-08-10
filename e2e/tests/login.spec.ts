import { test, expect } from '@playwright/test';

test.describe('Nextcloud login', () => {
  test('status.php reports the installation as complete', async ({ request }) => {
    const response = await request.get('/status.php');
    expect(response.ok()).toBeTruthy();

    const body = await response.json();
    expect(body.installed).toBe(true);
    expect(body.maintenance).toBe(false);
  });

  test('login page loads and shows the login form', async ({ page }) => {
    const response = await page.goto('/login');
    expect(response?.ok()).toBeTruthy();
    await expect(page).toHaveTitle(/Nextcloud/i);
    await expect(page.locator('input[name="user"]')).toBeVisible();
    await expect(page.locator('input[name="password"]')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('valid credentials grant access to the dashboard', async ({ page }) => {
    await page.goto('/login');

    // The Nextcloud login form is a Vue component. Wait until the fields are
    // actually editable (hydrated) before filling, otherwise the values can be
    // cleared by hydration and the submit silently does nothing.
    const user = page.locator('input[name="user"]');
    const password = page.locator('input[name="password"]');
    await expect(user).toBeEditable();
    await expect(password).toBeEditable();

    await user.fill('admin');
    // Must match SECRET_VALUE set by the workflow's "Adjust values" step.
    await password.fill(process.env.NEXTCLOUD_PASSWORD ?? "secret");

    await page.locator('button[type="submit"]').click();

    // On success Nextcloud navigates away from /login (client-side or full
    // redirect). On failure it re-renders /login with a warning. Wait for
    // either outcome instead of racing networkidle.
    const leftLogin = page
      .waitForURL((url: URL) => !url.pathname.includes('/login'), {
        timeout: 30_000,
      })
      .then(() => true)
      .catch(() => false);
    const sawWarning = page
      .locator('.warning, [data-login-form-message]')
      .first()
      .waitFor({ state: 'visible', timeout: 30_000 })
      .then(() => true)
      .catch(() => false);

    const redirected = await Promise.race([leftLogin, sawWarning]);

    // If we're still on /login, surface as much context as possible instead of
    // a bare timeout.
    if (!redirected || new URL(page.url()).pathname.includes('/login')) {
      const warning =
        (await page
          .locator('.warning, [data-login-form-message]')
          .first()
          .textContent()
          .catch(() => null)) ?? null;
      const bodyText = (
        (await page.locator('body').textContent().catch(() => '')) ?? ''
      )
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 500);
      throw new Error(
        `Login did not redirect away from /login (url: ${page.url()}). ` +
          `Warning: ${warning?.trim() || '(none)'} | Body: ${bodyText}`,
      );
    }

    // The top navigation bar is the canonical indicator of a logged-in session
    await expect(page.locator('#header')).toBeVisible();
  });
});
