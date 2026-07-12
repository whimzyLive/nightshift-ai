import { render, screen } from '@testing-library/react';

import { CountUp } from './count-up';

function mockMatchMedia(reduced: boolean) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: query === '(prefers-reduced-motion: reduce)' ? reduced : false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

class FakeIntersectionObserver implements IntersectionObserver {
  readonly root = null;
  readonly rootMargin = '';
  readonly thresholds: ReadonlyArray<number> = [];
  observe = jest.fn();
  unobserve = jest.fn();
  disconnect = jest.fn();
  takeRecords = jest.fn(() => []);
}

describe('CountUp', () => {
  afterEach(() => {
    // @ts-expect-error test-only cleanup of a possibly-installed global
    delete window.IntersectionObserver;
  });

  it('renders 0 on initial render and waits for the observer to fire', () => {
    mockMatchMedia(false);
    window.IntersectionObserver =
      FakeIntersectionObserver as unknown as typeof IntersectionObserver;

    render(<CountUp value={11} />);
    expect(screen.getByText('0')).toBeTruthy();
  });

  it('renders prefix and suffix alongside the initial value', () => {
    mockMatchMedia(false);
    window.IntersectionObserver =
      FakeIntersectionObserver as unknown as typeof IntersectionObserver;

    render(<CountUp value={60} suffix=" seconds" />);
    expect(screen.getByText('0 seconds')).toBeTruthy();
  });

  it('renders the final value immediately under reduced motion, without needing an observer', () => {
    mockMatchMedia(true);
    // Intentionally no IntersectionObserver installed.

    render(<CountUp value={11} />);
    expect(screen.getByText('11')).toBeTruthy();
  });

  it('renders the final value immediately when IntersectionObserver is unsupported', () => {
    mockMatchMedia(false);
    // No IntersectionObserver installed — degrade path.

    render(<CountUp value={10} />);
    expect(screen.getByText('10')).toBeTruthy();
  });
});
