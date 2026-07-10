import { render, screen } from '@testing-library/react';
import { TerminalWindow } from '../src/components/sections/terminal-window';
import { TERMINAL_LINES } from '../src/lib/sections-content';

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

jest.mock('gsap', () => {
  const timeline = {
    from: jest.fn().mockReturnThis(),
    kill: jest.fn(),
    scrollTrigger: { kill: jest.fn() },
  };
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
            if (Object.values(conditions).some(Boolean)) {
              handler({ conditions });
            }
          },
        ),
        revert: jest.fn(),
      })),
      timeline: jest.fn(() => timeline),
      set: jest.fn(),
    },
  };
});

jest.mock('gsap/ScrollTrigger', () => ({ ScrollTrigger: {} }));

describe('TerminalWindow', () => {
  beforeEach(() => {
    capturedQueries = undefined;
    jest.clearAllMocks();
    stubMatchMedia(null);
  });

  it('renders the traffic-light window chrome and every pipeline line', () => {
    const { container } = render(
      <TerminalWindow title="zsh — nightshift" lines={TERMINAL_LINES} />,
    );

    expect(screen.getByText('zsh — nightshift')).toBeTruthy();
    const normalizedBody = container.textContent?.replace(/\s+/g, ' ');
    TERMINAL_LINES.forEach((line) => {
      expect(normalizedBody).toContain(line.text.replace(/\s+/g, ' '));
    });
  });

  it('shows the ✓ marks for the spec → plan → impl → review stages', () => {
    const { container } = render(<TerminalWindow lines={TERMINAL_LINES} />);

    const checkedLines = TERMINAL_LINES.filter((line) =>
      line.text.includes('✓'),
    );
    expect(checkedLines.length).toBe(4);
    const checkMarkCount = (container.textContent?.match(/✓/g) ?? []).length;
    expect(checkMarkCount).toBe(4);
  });

  it('registers both a reduce and a no-preference matchMedia condition', () => {
    render(<TerminalWindow lines={TERMINAL_LINES} />);

    expect(capturedQueries).toEqual(
      expect.objectContaining({
        reduceMotion: '(prefers-reduced-motion: reduce)',
        allowMotion: '(prefers-reduced-motion: no-preference)',
      }),
    );
  });

  it('does nothing (no looping timeline) when reduced motion is preferred — lines are already visible by default', () => {
    stubMatchMedia('(prefers-reduced-motion: reduce)');
    const gsap = jest.requireMock('gsap').default;

    render(<TerminalWindow lines={TERMINAL_LINES} />);

    expect(gsap.set).not.toHaveBeenCalled();
    expect(gsap.timeline).not.toHaveBeenCalled();
  });

  it('builds a repeating reveal timeline for a default user with no motion preference', () => {
    stubMatchMedia('(prefers-reduced-motion: no-preference)');
    const gsap = jest.requireMock('gsap').default;

    render(<TerminalWindow lines={TERMINAL_LINES} />);

    expect(gsap.timeline).toHaveBeenCalledWith(
      expect.objectContaining({
        repeat: -1,
        scrollTrigger: expect.objectContaining({
          toggleActions: expect.any(String),
        }),
      }),
    );
  });
});
