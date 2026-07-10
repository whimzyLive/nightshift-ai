import { test, expect } from '@playwright/test';

test('renders the CMS-driven home page with stable chrome', async ({
  page,
}) => {
  const response = await page.goto('/');

  expect(response?.ok()).toBeTruthy();

  // The hero/section copy is CMS-sourced and renders empty strings against an
  // empty CMS, so assert on structural chrome instead of hero text.
  await expect(page.getByRole('banner')).toBeVisible();
  await expect(page.getByRole('main')).toBeVisible();
  await expect(page.getByRole('contentinfo')).toBeVisible();
});
