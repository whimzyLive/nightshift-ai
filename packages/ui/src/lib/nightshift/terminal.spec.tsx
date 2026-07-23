import { act, render, screen, waitFor } from '@testing-library/react';

import { Terminal } from './terminal';
import type { TerminalLine } from './terminal';

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

const LINES: TerminalLine[] = [
  { prompt: '$', text: '/auto PROJ-142' },
  { text: 'Reading ticket…', tone: 'muted' },
  { text: '→ opened PR #318', tone: 'success' },
];

describe('Terminal', () => {
  it('renders the title and only line 1 on initial render (deterministic server frame)', () => {
    mockMatchMedia(false);
    render(<Terminal title="zsh — acme-api · claude code" lines={LINES} />);

    expect(screen.getByText('zsh — acme-api · claude code')).toBeTruthy();
    expect(screen.getByText('/auto PROJ-142')).toBeTruthy();
    expect(screen.queryByText('Reading ticket…')).toBeNull();
    expect(screen.queryByText('→ opened PR #318')).toBeNull();
  });

  it('renders all lines immediately with no reveal timer under reduced motion', () => {
    mockMatchMedia(true);
    const setIntervalSpy = jest.spyOn(window, 'setInterval');

    render(<Terminal title="zsh — acme-api · claude code" lines={LINES} />);

    expect(screen.getByText('/auto PROJ-142')).toBeTruthy();
    expect(screen.getByText('Reading ticket…')).toBeTruthy();
    expect(screen.getByText('→ opened PR #318')).toBeTruthy();
    expect(setIntervalSpy).not.toHaveBeenCalled();

    setIntervalSpy.mockRestore();
  });

  describe('C3 revealOnView', () => {
    afterEach(() => {
      FakeIntersectionObserver.instances = [];
      // @ts-expect-error test-only cleanup of a possibly-installed global
      delete window.IntersectionObserver;
    });

    it('defers the scripted reveal until it scrolls into view', () => {
      mockMatchMedia(false);
      window.IntersectionObserver =
        FakeIntersectionObserver as unknown as typeof IntersectionObserver;

      render(
        <Terminal
          title="zsh — acme-api · claude code"
          lines={LINES}
          revealOnView
        />,
      );

      // Not yet intersecting — stays on the deterministic first-line frame.
      expect(screen.getByText('/auto PROJ-142')).toBeTruthy();
      expect(screen.queryByText('Reading ticket…')).toBeNull();
    });

    it('starts revealing once the observer reports an intersection', async () => {
      mockMatchMedia(false);
      window.IntersectionObserver =
        FakeIntersectionObserver as unknown as typeof IntersectionObserver;

      render(
        <Terminal
          title="zsh — acme-api · claude code"
          lines={LINES}
          revealOnView
        />,
      );
      const [observer] = FakeIntersectionObserver.instances;
      act(() => {
        observer.callback(
          [{ isIntersecting: true } as IntersectionObserverEntry],
          observer,
        );
      });

      await waitFor(
        () => expect(screen.getByText('→ opened PR #318')).toBeTruthy(),
        { timeout: 3000 },
      );
    });

    it('still renders every line immediately under reduced motion, regardless of viewport', () => {
      mockMatchMedia(true);
      // Intentionally no IntersectionObserver installed.

      render(
        <Terminal
          title="zsh — acme-api · claude code"
          lines={LINES}
          revealOnView
        />,
      );

      expect(screen.getByText('/auto PROJ-142')).toBeTruthy();
      expect(screen.getByText('Reading ticket…')).toBeTruthy();
      expect(screen.getByText('→ opened PR #318')).toBeTruthy();
    });
  });
});
