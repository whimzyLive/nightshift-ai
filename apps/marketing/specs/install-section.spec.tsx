import { render, screen } from '@testing-library/react';
import { InstallSection } from '../src/components/sections/install-section';
import { INSTALL_COMMANDS } from '../src/lib/sections-content';

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

describe('InstallSection', () => {
  beforeEach(() => {
    capturedQueries = undefined;
    jest.clearAllMocks();
    stubMatchMedia(null);
  });

  it('renders the mono eyebrow, heading, both install commands, and the CTA', () => {
    render(<InstallSection />);

    expect(screen.getByText('// install in 60 seconds')).toBeTruthy();
    expect(
      screen.getByRole('heading', {
        level: 2,
        name: /two lines in any claude code session/i,
      }),
    ).toBeTruthy();
    INSTALL_COMMANDS.forEach((command) => {
      expect(screen.getByText(command)).toBeTruthy();
    });
    const cta = screen.getByRole('link', { name: /view on github/i });
    expect(cta.getAttribute('href')).toBe(
      'https://github.com/whimzyLive/nightshift-ai',
    );
  });

  it('registers both a reduce and a no-preference matchMedia condition for the section reveal', () => {
    render(<InstallSection />);

    expect(capturedQueries).toEqual(
      expect.objectContaining({
        reduceMotion: '(prefers-reduced-motion: reduce)',
        allowMotion: '(prefers-reduced-motion: no-preference)',
      }),
    );
  });

  it('does nothing when reduced motion is preferred — content is already visible by default', () => {
    stubMatchMedia('(prefers-reduced-motion: reduce)');
    const gsap = jest.requireMock('gsap').default;

    render(<InstallSection />);

    expect(gsap.set).not.toHaveBeenCalled();
    expect(gsap.from).not.toHaveBeenCalled();
  });

  it('reveals the section via a ScrollTrigger tween for a default user with no motion preference, clearing inline styles on complete', () => {
    stubMatchMedia('(prefers-reduced-motion: no-preference)');
    const gsap = jest.requireMock('gsap').default;

    render(<InstallSection />);

    expect(gsap.from).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        autoAlpha: 0,
        y: 24,
        clearProps: 'transform,opacity,visibility',
        scrollTrigger: expect.objectContaining({ once: true }),
      }),
    );
  });
});
