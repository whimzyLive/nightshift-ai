import { render } from '@testing-library/react';

import { NightSky } from './night-sky';

describe('NightSky', () => {
  it('is hidden from assistive tech (decorative background)', () => {
    const { container } = render(<NightSky />);
    expect(container.firstChild).not.toBeNull();
    expect(
      (container.firstChild as HTMLElement).getAttribute('aria-hidden'),
    ).toBe('true');
  });

  it('uses the calmer subpage opacity token by default', () => {
    const { container } = render(<NightSky />);
    const el = container.firstChild as HTMLElement;
    expect(el.className).toContain('opacity-[var(--sky-opacity-subpage)]');
  });

  it('raises to the home opacity token when variant="home"', () => {
    const { container } = render(<NightSky variant="home" />);
    const el = container.firstChild as HTMLElement;
    expect(el.className).toContain('opacity-[var(--sky-opacity-home)]');
  });

  describe('A1 dawn backdrop', () => {
    it('renders the dawn backdrop only for variant="home"', () => {
      const { queryByTestId, unmount } = render(<NightSky variant="home" />);
      expect(queryByTestId('dawn-backdrop')).toBeTruthy();
      unmount();

      const { queryByTestId: queryDefault } = render(<NightSky />);
      expect(queryDefault('dawn-backdrop')).toBeNull();
    });

    it('paints the dawn backdrop with the terracotta accent hue (--terra-500 rgb triplet)', () => {
      const { getByTestId } = render(<NightSky variant="home" />);
      const backdrop = getByTestId('dawn-backdrop');
      // Same RGB as --terra-glow/--terra-tint/--terra-500 (217,119,87), at a
      // richer alpha so the pre-dawn wash is clearly visible.
      expect(backdrop.getAttribute('style')).toContain('217,119,87');
      expect(backdrop.getAttribute('aria-hidden')).toBe('true');
    });
  });

  describe('A1 dawn sun + clouds', () => {
    it('renders the sun disc and cloud wisps only for variant="home"', () => {
      const { queryByTestId, queryAllByTestId, unmount } = render(
        <NightSky variant="home" />,
      );
      expect(queryByTestId('dawn-sun')).toBeTruthy();
      expect(queryAllByTestId('dawn-cloud').length).toBeGreaterThanOrEqual(2);
      expect(queryAllByTestId('dawn-cloud').length).toBeLessThanOrEqual(4);
      unmount();

      const { queryByTestId: queryDefaultSun } = render(<NightSky />);
      expect(queryDefaultSun('dawn-sun')).toBeNull();
    });

    it('paints the sun with the low-key terracotta tokens, not a bright yellow disc', () => {
      const { getByTestId } = render(<NightSky variant="home" />);
      const sun = getByTestId('dawn-sun');
      expect(sun.getAttribute('style')).toContain('--terra-300');
      expect(sun.getAttribute('style')).toContain('--terra-500');
      expect(sun.getAttribute('style')).toContain('--terra-glow');
      expect(sun.getAttribute('aria-hidden')).toBe('true');
    });

    it('starts hidden (opacity 0) at the top of the page, before the rise range begins', () => {
      // Motion's `useReducedMotion()` is a module-level singleton (see the
      // web-engineer memory entry on this) — it can't be forced per-test in
      // this file, so this asserts the honest default (non-reduced) state at
      // `scrollYProgress = 0` rather than a fabricated reduced-motion case:
      // useTransform's default clamp holds the sun at its pre-range output
      // (opacity 0) until scroll reaches SUN_RISE_RANGE's start.
      const { getByTestId } = render(<NightSky variant="home" />);
      const sun = getByTestId('dawn-sun');
      expect(sun.style.opacity).toBe('0');
    });
  });
});
