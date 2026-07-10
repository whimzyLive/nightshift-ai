import { test, expect } from '@playwright/test';

test('renders the home page', async ({ page }) => {
  await page.goto('/');

  await expect(
    page.getByRole('heading', { name: 'Hello World' }),
  ).toBeVisible();
});
