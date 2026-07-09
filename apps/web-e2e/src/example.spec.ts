import { test, expect } from '@playwright/test';

test('renders the home page', async ({ page }) => {
  await page.goto('/');

  // The app's main heading should render once the page is interactive.
  await expect(page.locator('h1').first()).toBeVisible();
});
