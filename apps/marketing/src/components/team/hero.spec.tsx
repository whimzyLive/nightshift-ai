import { render, screen } from '@testing-library/react';

import { TeamHero } from './hero';

describe('TeamHero', () => {
  it('renders headline, eyebrow and stats line', () => {
    render(<TeamHero />);
    expect(
      screen.getByRole('heading', {
        name: 'Meet the team that works while you sleep',
      }),
    ).toBeTruthy();
    expect(
      screen.getByText(
        /11 agents on staff · 1 opt-in specialist · hallucinating across roles: not permitted/,
      ),
    ).toBeTruthy();
    expect(
      screen.getByRole('link', { name: 'Home' }).getAttribute('href'),
    ).toBe('/');
  });
});
