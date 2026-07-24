import { render } from '@testing-library/react';

import { PhraseMarquee } from './phrase-marquee';

function mockMatchMedia(reduced: boolean) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: query === '(prefers-reduced-motion: reduce)' ? reduced : false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

describe('PhraseMarquee', () => {
  it('renders the phrase line, hidden from assistive tech', () => {
    mockMatchMedia(false);
    const { container } = render(<PhraseMarquee />);
    expect(container.firstElementChild?.getAttribute('aria-hidden')).toBe(
      'true',
    );
    expect(container.textContent).toContain('you sleep, it ships');
  });

  describe('D1 velocity-responsive skew', () => {
    it('applies no skew under reduced motion, regardless of scroll velocity', () => {
      mockMatchMedia(true);
      const { container } = render(<PhraseMarquee />);
      const track = container.querySelector(
        '.flex.w-max',
      ) as HTMLElement | null;
      expect(track).toBeTruthy();
      expect(track?.style.transform ?? '').not.toContain('skew');
    });

    it('does not throw and keeps the base track present when not reduced', () => {
      mockMatchMedia(false);
      const { container } = render(<PhraseMarquee />);
      const track = container.querySelector('.flex.w-max');
      expect(track).toBeTruthy();
    });
  });
});
