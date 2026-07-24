import { act, render, waitFor } from '@testing-library/react';

import { RollingNumber } from './rolling-number';

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
  static instances: FakeIntersectionObserver[] = [];
  callback: IntersectionObserverCallback;
  constructor(callback: IntersectionObserverCallback) {
    this.callback = callback;
    FakeIntersectionObserver.instances.push(this);
  }
  observe = jest.fn();
  unobserve = jest.fn();
  disconnect = jest.fn();
  takeRecords = jest.fn(() => []);
}

describe('RollingNumber', () => {
  afterEach(() => {
    FakeIntersectionObserver.instances = [];
    // @ts-expect-error test-only cleanup of a possibly-installed global
    delete window.IntersectionObserver;
  });

  it('renders placeholder zero digits before the observer fires', () => {
    mockMatchMedia(false);
    window.IntersectionObserver =
      FakeIntersectionObserver as unknown as typeof IntersectionObserver;

    const { container } = render(<RollingNumber value={11} />);
    expect(container.textContent).toBe('00');
  });

  it('rolls in the final digits once the observer reports an intersection', async () => {
    mockMatchMedia(false);
    window.IntersectionObserver =
      FakeIntersectionObserver as unknown as typeof IntersectionObserver;

    const { container } = render(<RollingNumber value={11} />);
    const [observer] = FakeIntersectionObserver.instances;
    act(() => {
      observer.callback(
        [{ isIntersecting: true } as IntersectionObserverEntry],
        observer,
      );
    });

    await waitFor(() => expect(container.textContent).toBe('11'));
  });

  it('renders prefix and suffix alongside the final value', () => {
    mockMatchMedia(true);
    const { container } = render(
      <RollingNumber value={60} suffix=" seconds" />,
    );
    expect(container.textContent).toBe('60 seconds');
  });

  it('renders the final value immediately under reduced motion, without needing an observer', () => {
    mockMatchMedia(true);
    // Intentionally no IntersectionObserver installed.

    const { container } = render(<RollingNumber value={11} />);
    expect(container.textContent).toBe('11');
  });

  it('renders the final value immediately when IntersectionObserver is unsupported', () => {
    mockMatchMedia(false);
    // No IntersectionObserver installed — degrade path.

    const { container } = render(<RollingNumber value={10} />);
    expect(container.textContent).toBe('10');
  });
});
