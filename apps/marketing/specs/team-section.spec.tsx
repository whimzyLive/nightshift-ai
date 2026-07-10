import { render, screen } from '@testing-library/react';
import { TeamSection } from '../src/components/sections/team-section';
import { TEAM } from '../src/lib/sections-content';

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
    set: jest.fn(),
  },
}));

jest.mock('gsap/ScrollTrigger', () => ({ ScrollTrigger: {} }));

describe('TeamSection', () => {
  beforeEach(() => {
    capturedQueries = undefined;
    jest.clearAllMocks();
    stubMatchMedia(null);
  });

  it('renders the mono eyebrow, heading, and all 11 agent cards', () => {
    render(<TeamSection />);

    expect(screen.getByText('// meet your team')).toBeTruthy();
    expect(
      screen.getByRole('heading', {
        level: 2,
        name: /eleven specialists, one terminal/i,
      }),
    ).toBeTruthy();
    TEAM.forEach((agent) => {
      expect(screen.getByTestId(`agent-card-${agent.name}`)).toBeTruthy();
    });
  });

  it('registers both a reduce and a no-preference matchMedia condition for the section reveal', () => {
    render(<TeamSection />);

    expect(capturedQueries).toEqual(
      expect.objectContaining({
        reduceMotion: '(prefers-reduced-motion: reduce)',
        allowMotion: '(prefers-reduced-motion: no-preference)',
      }),
    );
  });

  it('shows the standby label only for standby agents', () => {
    render(<TeamSection />);

    const standbyAgents = TEAM.filter((a) => a.standby);
    const activeAgents = TEAM.filter((a) => !a.standby);

    standbyAgents.forEach((agent) => {
      const card = screen.getByTestId(`agent-card-${agent.name}`);
      expect(card.textContent).toContain('standby');
    });
    activeAgents.forEach((agent) => {
      const card = screen.getByTestId(`agent-card-${agent.name}`);
      expect(card.textContent).not.toContain('standby');
    });
  });

  it('shows cards in their final visible state immediately when reduced motion is preferred', () => {
    stubMatchMedia('(prefers-reduced-motion: reduce)');
    const gsap = jest.requireMock('gsap').default;

    render(<TeamSection />);

    expect(gsap.set).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ autoAlpha: 1, y: 0 }),
    );
    expect(gsap.from).not.toHaveBeenCalled();
  });

  it('reveals cards via a staggered ScrollTrigger tween for a default user with no motion preference', () => {
    stubMatchMedia('(prefers-reduced-motion: no-preference)');
    const gsap = jest.requireMock('gsap').default;

    render(<TeamSection />);

    expect(gsap.from).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        autoAlpha: 0,
        y: 24,
        stagger: expect.any(Number),
        scrollTrigger: expect.objectContaining({ once: true }),
      }),
    );
  });
});
