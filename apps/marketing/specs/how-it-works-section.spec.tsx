import { render, screen } from '@testing-library/react';
import { HowItWorksSection } from '../src/components/sections/how-it-works-section';
import { PIPELINE_IDEAS } from '../src/lib/sections-content';

let capturedQueries: Record<string, string> | undefined;

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
    from: jest.fn(() => ({
      kill: jest.fn(),
      scrollTrigger: { kill: jest.fn() },
    })),
    to: jest.fn(() => ({
      kill: jest.fn(),
      scrollTrigger: { kill: jest.fn() },
    })),
    // The section also renders TerminalWindow and StatCounter, which build
    // their own timelines/tweens independently — stub timeline() too so
    // mounting the whole section doesn't throw.
    timeline: jest.fn(() => ({
      from: jest.fn().mockReturnThis(),
      kill: jest.fn(),
      scrollTrigger: { kill: jest.fn() },
    })),
    set: jest.fn(),
  },
}));

jest.mock('gsap/ScrollTrigger', () => ({ ScrollTrigger: {} }));

describe('HowItWorksSection', () => {
  beforeEach(() => {
    capturedQueries = undefined;
    jest.clearAllMocks();
    stubMatchMedia(null);
  });

  it('renders the mono eyebrow, heading, idea cards, pipeline stages, terminal, and stats', () => {
    render(<HowItWorksSection />);

    expect(screen.getByText('// how it works')).toBeTruthy();
    expect(
      screen.getByRole('heading', {
        level: 2,
        name: /spec before plan, plan before code, review before merge/i,
      }),
    ).toBeTruthy();
    expect(screen.getAllByTestId('idea-card')).toHaveLength(
      PIPELINE_IDEAS.length,
    );
    expect(screen.getByTestId('terminal-window')).toBeTruthy();
    expect(screen.getAllByTestId('stat-counter').length).toBeGreaterThan(0);
  });

  it('registers both a reduce and a no-preference matchMedia condition for the section reveal', () => {
    render(<HowItWorksSection />);

    expect(capturedQueries).toEqual(
      expect.objectContaining({
        reduceMotion: '(prefers-reduced-motion: reduce)',
        allowMotion: '(prefers-reduced-motion: no-preference)',
      }),
    );
  });

  it('does nothing when reduced motion is preferred — cards are already visible by default', () => {
    stubMatchMedia('(prefers-reduced-motion: reduce)');
    const gsap = jest.requireMock('gsap').default;

    render(<HowItWorksSection />);

    expect(gsap.set).not.toHaveBeenCalled();
    expect(gsap.from).not.toHaveBeenCalled();
  });

  it('reveals cards via a staggered ScrollTrigger tween for a default user with no motion preference, clearing inline styles on complete', () => {
    stubMatchMedia('(prefers-reduced-motion: no-preference)');
    const gsap = jest.requireMock('gsap').default;

    render(<HowItWorksSection />);

    expect(gsap.from).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        autoAlpha: 0,
        y: 24,
        stagger: expect.any(Number),
        clearProps: 'transform,opacity,visibility',
        scrollTrigger: expect.objectContaining({ once: true }),
      }),
    );
  });
});
