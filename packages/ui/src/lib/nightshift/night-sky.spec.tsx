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

    it('paints a vibrant sunrise wash — amber-400 through terra-500/terra-700 RGB triplets', () => {
      const { getByTestId } = render(<NightSky variant="home" />);
      const backdrop = getByTestId('dawn-backdrop');
      const style = backdrop.getAttribute('style') ?? '';
      // --amber-400 (224,164,88), --terra-500 (217,119,87), --terra-700
      // (157,77,58) — same RGB triplets as the design-token scale, at richer
      // alphas than the subtle variant so the sunrise wash clearly reads.
      expect(style).toContain('224,164,88');
      expect(style).toContain('217,119,87');
      expect(style).toContain('157,77,58');
      expect(backdrop.getAttribute('aria-hidden')).toBe('true');
    });
  });

  describe('A1 vibrant morning — sun disc/rays + clouds', () => {
    it('renders the sun disc, its rays, and 3-5 clouds only for variant="home"', () => {
      const { queryByTestId, queryAllByTestId, unmount } = render(
        <NightSky variant="home" />,
      );
      expect(queryByTestId('dawn-sun')).toBeTruthy();
      expect(queryByTestId('dawn-sun-rays')).toBeTruthy();
      expect(queryAllByTestId('dawn-cloud').length).toBeGreaterThanOrEqual(3);
      expect(queryAllByTestId('dawn-cloud').length).toBeLessThanOrEqual(5);
      unmount();

      const { queryByTestId: queryDefaultSun } = render(<NightSky />);
      expect(queryDefaultSun('dawn-sun')).toBeNull();
      expect(queryDefaultSun('dawn-sun-rays')).toBeNull();
    });

    it('paints a proper bright sun disc — warm core (moon-100/amber-400) through terracotta, with a static corona glow', () => {
      const { getByTestId } = render(<NightSky variant="home" />);
      const sun = getByTestId('dawn-sun');
      const style = sun.getAttribute('style') ?? '';
      expect(style).toContain('--moon-100');
      expect(style).toContain('--amber-400');
      expect(style).toContain('--terra-400');
      expect(style).toContain('--terra-600');
      // Corona/halo glow — a static (never-animated) box-shadow, same
      // convention as the moon's own outer glow.
      expect(style).toContain('box-shadow');
      expect(sun.getAttribute('aria-hidden')).toBe('true');
    });

    it('paints the sun rays as a static repeating-conic-gradient using the amber tint token', () => {
      const { getByTestId } = render(<NightSky variant="home" />);
      const rays = getByTestId('dawn-sun-rays');
      expect(rays.getAttribute('style')).toContain('--amber-tint');
      expect(rays.getAttribute('aria-hidden')).toBe('true');
    });

    it('paints clouds as defined puff shapes (warm-lit gradient + static box-shadow lobes), not a flat low-opacity wisp', () => {
      const { getAllByTestId } = render(<NightSky variant="home" />);
      for (const cloud of getAllByTestId('dawn-cloud')) {
        const style = cloud.getAttribute('style') ?? '';
        expect(style).toContain('linear-gradient');
        expect(style).toContain('box-shadow');
        expect(cloud.getAttribute('aria-hidden')).toBe('true');
      }
    });

    it('starts hidden (opacity 0) at the top of the page, before the rise range begins', () => {
      // Motion's `useReducedMotion()` is a module-level singleton (see the
      // web-engineer memory entry on this) — it can't be forced per-test in
      // this file, so this asserts the honest default (non-reduced) state at
      // `scrollYProgress = 0` rather than a fabricated reduced-motion case:
      // useTransform's default clamp holds the sun (and rays/clouds, which
      // share the same motion value) at their pre-range output (opacity 0)
      // until scroll reaches SUN_RISE_RANGE's start.
      const { getByTestId, getAllByTestId } = render(
        <NightSky variant="home" />,
      );
      expect(getByTestId('dawn-sun').style.opacity).toBe('0');
      expect(getByTestId('dawn-sun-rays').style.opacity).toBe('0');
      for (const cloud of getAllByTestId('dawn-cloud')) {
        expect(cloud.style.opacity).toBe('0');
      }
    });
  });
});
