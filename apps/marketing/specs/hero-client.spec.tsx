import { render, screen } from '@testing-library/react';
import { HeroClient } from '../src/components/hero/hero-client';

let capturedQueries: Record<string, string> | undefined;

/**
 * Stubs `window.matchMedia` so the mocked `gsap.matchMedia().add()` below
 * decides whether to invoke the handler using real matching semantics
 * instead of a hand-picked boolean — mirroring GSAP's real contract (see
 * gsap-core.js `MatchMedia.add`: `active && func(...)`, where `active` is
 * only set when at least one named condition's query actually matches).
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

jest.mock('gsap', () => {
  const timeline = { from: jest.fn().mockReturnThis(), kill: jest.fn() };
  return {
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
            // A single unmatched condition must NOT fire the handler — this
            // is exactly the contract the original bug violated (only
            // `reduceMotion` registered, so a default user matched nothing).
            if (Object.values(conditions).some(Boolean)) {
              handler({ conditions });
            }
          },
        ),
        revert: jest.fn(),
      })),
      timeline: jest.fn(() => timeline),
      quickTo: jest.fn(() => jest.fn()),
      to: jest.fn(() => ({
        kill: jest.fn(),
        scrollTrigger: { kill: jest.fn() },
      })),
      set: jest.fn(),
    },
  };
});

jest.mock('gsap/ScrollTrigger', () => ({ ScrollTrigger: {} }));

const props = {
  headline: 'Your AI software team that ships while you sleep',
  subhead: 'A test subhead sourced from Payload.',
  ctaLabel: 'Install the plugin',
  ctaHref: 'https://github.com/whimzyLive/nightshift-ai',
};

describe('HeroClient', () => {
  beforeEach(() => {
    capturedQueries = undefined;
    jest.clearAllMocks();
    // jsdom has no built-in matchMedia — default to "nothing matches" so
    // tests that don't care about motion preference still render safely.
    stubMatchMedia(null);
  });

  it('renders the CMS-sourced headline, subhead, and CTA', () => {
    render(<HeroClient {...props} />);

    expect(
      screen.getByRole('heading', { level: 1, name: props.headline }),
    ).toBeTruthy();
    expect(screen.getByText(props.subhead)).toBeTruthy();

    const cta = screen.getByRole('link', { name: props.ctaLabel });
    expect(cta.getAttribute('href')).toBe(props.ctaHref);
  });

  it('hides the decorative sky backdrop from assistive tech', () => {
    const { container } = render(<HeroClient {...props} />);
    const stage = container.querySelector('[aria-hidden="true"]');

    expect(stage).not.toBeNull();
  });

  it('registers both a reduce and a no-preference matchMedia condition on mount', () => {
    const gsap = jest.requireMock('gsap').default;

    render(<HeroClient {...props} />);

    expect(gsap.matchMedia).toHaveBeenCalled();
    expect(capturedQueries).toEqual(
      expect.objectContaining({
        reduceMotion: '(prefers-reduced-motion: reduce)',
        allowMotion: '(prefers-reduced-motion: no-preference)',
      }),
    );
  });

  it('skips the entrance timeline and jumps to the final state when reduced motion is preferred', () => {
    stubMatchMedia('(prefers-reduced-motion: reduce)');
    const gsap = jest.requireMock('gsap').default;

    render(<HeroClient {...props} />);

    expect(gsap.set).toHaveBeenCalled();
    expect(gsap.timeline).not.toHaveBeenCalled();
  });

  // Regression test for the bug where a default user (no explicit motion
  // preference either way) matched no registered condition and the entrance
  // timeline silently never ran. With only `reduceMotion` registered, this
  // matches nothing and gsap.timeline is never called — this test fails
  // against that broken registration.
  it('runs the entrance timeline and mouse-parallax setup for a default user with no motion preference', () => {
    stubMatchMedia('(prefers-reduced-motion: no-preference)');
    const gsap = jest.requireMock('gsap').default;

    render(<HeroClient {...props} />);

    expect(gsap.timeline).toHaveBeenCalled();
    expect(gsap.quickTo).toHaveBeenCalledWith(
      expect.anything(),
      'rotationX',
      expect.any(Object),
    );
    expect(gsap.quickTo).toHaveBeenCalledWith(
      expect.anything(),
      'rotationY',
      expect.any(Object),
    );
  });
});
