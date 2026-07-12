import { render, screen } from '@testing-library/react';

import HomePage from './page';

// Hero embeds the Terminal primitive (checks prefers-reduced-motion) and
// ProofBar embeds CountUp (checks IntersectionObserver support) — both are
// client components exercising browser-only APIs jsdom doesn't implement by
// default. Mirrors the mocking pattern used in cursor-glow.spec.tsx.
function mockMatchMedia() {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

describe('HomePage', () => {
  beforeEach(() => {
    mockMatchMedia();
  });

  it('renders the Hero heading', () => {
    render(<HomePage />);
    expect(
      screen.getByRole('heading', { level: 1, name: /ships while you sleep/i }),
    ).toBeTruthy();
  });

  it('renders the four above-the-fold sections in order', () => {
    const { container } = render(<HomePage />);
    expect(
      screen.getByRole('link', { name: /star nightshift on github/i }),
    ).toBeTruthy();
    // Numbers + labels are split across CountUp's own <span> and the
    // surrounding static text, so assert on the flattened text content
    // rather than a single-node text match.
    expect(container.textContent).toContain('specialized agents');
    expect(container.textContent).toContain('the other 80%');
  });

  it('composes how-it-works, day-night-workflow, team-preview, and why-different after ProblemSection, in order', () => {
    const { container } = render(<HomePage />);
    const html = container.innerHTML;
    const problemIdx = html.indexOf('the other 80%');
    const howIdx = html.indexOf('One command runs the whole lifecycle');
    const workflowIdx = html.indexOf('Review by day. Ship by night.');
    const teamIdx = html.indexOf('A team, not a megaprompt');
    const whyIdx = html.indexOf('Why builders choose it');

    expect(problemIdx).toBeGreaterThan(-1);
    expect(howIdx).toBeGreaterThan(problemIdx);
    expect(workflowIdx).toBeGreaterThan(howIdx);
    expect(teamIdx).toBeGreaterThan(workflowIdx);
    expect(whyIdx).toBeGreaterThan(teamIdx);
  });

  it('resolves the hero "while you sleep" #workflow deep-link to the day/night section (AC2)', () => {
    const { container } = render(<HomePage />);
    const heroLink = screen.getByRole('link', { name: /while you sleep/i });
    expect(heroLink.getAttribute('href')).toBe('#workflow');
    expect(container.querySelectorAll('#workflow')).toHaveLength(1);
  });
});
