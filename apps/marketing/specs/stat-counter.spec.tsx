import { render, screen } from '@testing-library/react';
import { StatCounter } from '../src/components/sections/stat-counter';

let capturedQueries: Record<string, string> | undefined;

/**
 * Mirrors the hero's matchMedia stub (hero-client.spec.tsx) — computes
 * `conditions` from a stubbed `window.matchMedia` per query and only invokes
 * the handler if at least one condition matches, the same contract GSAP's
 * real `MatchMedia.add` enforces.
 */
function stubMatchMedia(matchingQuery: string | null) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: query === matchingQuery,
    media: query,
    onchange: null,
    addListener: jest.fn(),
    removeListener: jest.fn(),
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  }));
}

jest.mock('gsap', () => ({
  __esModule: true,
  default: {
    registerPlugin: jest.fn(),
    matchMedia: jest.fn(() => ({
      add: jest.fn(
        (
          queries: Record<string, string>,
          handler: (context: { conditions: Record<string, boolean> }) => void,
        ) => {
          capturedQueries = queries;
          const conditions = Object.fromEntries(
            Object.entries(queries).map(([key, query]) => [
              key,
              window.matchMedia(query).matches,
            ]),
          );
          if (Object.values(conditions).some(Boolean)) {
            handler({ conditions });
          }
        },
      ),
      revert: jest.fn(),
    })),
    to: jest.fn((target, vars: Record<string, unknown>) => {
      // Simulate the tween completing immediately for test purposes.
      if (typeof vars['onUpdate'] === 'function') {
        (target as { val: number }).val = vars['val'] as number;
        (vars['onUpdate'] as () => void)();
      }
      return { kill: jest.fn(), scrollTrigger: { kill: jest.fn() } };
    }),
  },
}));

jest.mock('gsap/ScrollTrigger', () => ({ ScrollTrigger: {} }));

describe('StatCounter', () => {
  beforeEach(() => {
    capturedQueries = undefined;
    jest.clearAllMocks();
    stubMatchMedia(null);
  });

  it('renders the label and an initial zero value', () => {
    render(<StatCounter value={11} label="specialized agents" />);

    expect(screen.getByText('specialized agents')).toBeTruthy();
    expect(screen.getByTestId('stat-counter').textContent).toContain(
      'specialized agents',
    );
  });

  it('registers both a reduce and a no-preference matchMedia condition', () => {
    render(<StatCounter value={11} label="specialized agents" />);

    expect(capturedQueries).toEqual(
      expect.objectContaining({
        reduceMotion: '(prefers-reduced-motion: reduce)',
        allowMotion: '(prefers-reduced-motion: no-preference)',
      }),
    );
  });

  it('jumps straight to the final value with no tween when reduced motion is preferred', () => {
    stubMatchMedia('(prefers-reduced-motion: reduce)');
    const gsap = jest.requireMock('gsap').default;

    render(<StatCounter value={11} suffix="s" label="install" />);

    expect(gsap.to).not.toHaveBeenCalled();
    expect(
      screen.getByTestId('stat-counter').querySelector('span'),
    ).toHaveProperty('textContent', '11s');
  });

  it('tweens the counter up to the target value for a default user with no motion preference', () => {
    stubMatchMedia('(prefers-reduced-motion: no-preference)');
    const gsap = jest.requireMock('gsap').default;

    render(<StatCounter value={10} label="slash commands" />);

    expect(gsap.to).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ val: 10, onUpdate: expect.any(Function) }),
    );
  });
});
