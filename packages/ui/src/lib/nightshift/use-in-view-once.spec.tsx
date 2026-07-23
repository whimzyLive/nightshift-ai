import { act, render, screen } from '@testing-library/react';

import { useInViewOnce } from './use-in-view-once';

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

function Probe() {
  const { ref, inView, immediate } = useInViewOnce<HTMLSpanElement>();
  return (
    <span ref={ref} data-testid="probe">
      {inView ? 'in-view' : 'out-of-view'}:
      {immediate ? 'immediate' : 'observed'}
    </span>
  );
}

describe('useInViewOnce', () => {
  afterEach(() => {
    FakeIntersectionObserver.instances = [];
    // @ts-expect-error test-only cleanup of a possibly-installed global
    delete window.IntersectionObserver;
  });

  it('stays out of view until the observer reports an intersection', () => {
    mockMatchMedia(false);
    window.IntersectionObserver =
      FakeIntersectionObserver as unknown as typeof IntersectionObserver;

    render(<Probe />);
    expect(screen.getByTestId('probe').textContent).toBe(
      'out-of-view:observed',
    );
  });

  it('flips in view once the observer reports an intersection', () => {
    mockMatchMedia(false);
    window.IntersectionObserver =
      FakeIntersectionObserver as unknown as typeof IntersectionObserver;

    render(<Probe />);
    const [observer] = FakeIntersectionObserver.instances;
    act(() => {
      observer.callback(
        [{ isIntersecting: true } as IntersectionObserverEntry],
        observer,
      );
    });
    expect(screen.getByTestId('probe').textContent).toBe('in-view:observed');
  });

  it('reports in view immediately under reduced motion, without needing an observer', () => {
    mockMatchMedia(true);
    // Intentionally no IntersectionObserver installed.

    render(<Probe />);
    expect(screen.getByTestId('probe').textContent).toBe('in-view:immediate');
  });

  it('reports in view immediately when IntersectionObserver is unsupported', () => {
    mockMatchMedia(false);
    // No IntersectionObserver installed — degrade path.

    render(<Probe />);
    expect(screen.getByTestId('probe').textContent).toBe('in-view:immediate');
  });
});
