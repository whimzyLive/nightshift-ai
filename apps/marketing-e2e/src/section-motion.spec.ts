import { test, expect } from '@playwright/test';

// Real-browser guard for the class of bug jsdom can't see: a GSAP
// ScrollTrigger reveal that never actually mutates the element's computed
// transform (NA-21 AC7). The "meet your team" grid renders well below the
// fold, so on initial load its cards sit in GSAP's `.from()` start state
// (translateY applied as an inline transform via immediateRender) before
// any scroll happens — scrolling the card into view must then animate its
// computed transform to the settled end state.
test('scrolling an agent card into view mutates its computed transform', async ({
  page,
}) => {
  await page.goto('/');

  const card = page.getByTestId('agent-card-product-manager');

  const initialTransform = await card.evaluate(
    (el) => getComputedStyle(el).transform,
  );

  await card.scrollIntoViewIfNeeded();

  await expect
    .poll(async () => card.evaluate((el) => getComputedStyle(el).transform), {
      timeout: 5000,
    })
    .not.toBe(initialTransform);
});
