import { render, screen } from '@testing-library/react';

import { TeamCta } from './team-cta';

describe('TeamCta', () => {
  it('renders the heading', () => {
    render(<TeamCta />);
    expect(
      screen.getByRole('heading', {
        name: 'Hire the whole team in 60 seconds',
      }),
    ).toBeTruthy();
  });

  it('renders both install snippets', () => {
    render(<TeamCta />);
    expect(
      screen.getByText('/plugin marketplace add whimzyLive/nightshift-ai'),
    ).toBeTruthy();
    expect(screen.getByText('/plugin install sdlc@nightshift')).toBeTruthy();
  });

  it('renders the star button and back link', () => {
    render(<TeamCta />);
    const star = screen.getByRole('link', {
      name: '★ Star nightshift on GitHub',
    });
    expect(star.getAttribute('href')).toBe(
      'https://github.com/whimzyLive/nightshift-ai',
    );
    expect(star.getAttribute('rel')).toBe('noopener');
    expect(
      screen
        .getByRole('link', { name: '← Back to overview' })
        .getAttribute('href'),
    ).toBe('/');
  });
});
