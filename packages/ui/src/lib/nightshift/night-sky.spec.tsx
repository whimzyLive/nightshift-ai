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
});
