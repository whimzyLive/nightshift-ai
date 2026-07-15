import { render, screen } from '@testing-library/react';

import TeamPage from './page';
import * as mod from './page';

describe('TeamPage', () => {
  it('composes all five sections and stays statically rendered', () => {
    render(<TeamPage />);
    expect(
      screen.getByRole('heading', {
        name: 'Meet the team that works while you sleep',
      }),
    ).toBeTruthy();
    expect(screen.getByText('YOU')).toBeTruthy();
    expect(
      screen.getByText(/\.claude\/project\/agents\/<you>\.md/),
    ).toBeTruthy();
    expect(
      screen.getByRole('heading', {
        name: 'Hire the whole team in 60 seconds',
      }),
    ).toBeTruthy();
    expect((mod as Record<string, unknown>).dynamic).toBeUndefined();
  });
});
