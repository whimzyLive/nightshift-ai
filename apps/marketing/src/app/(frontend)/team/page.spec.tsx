import { render, screen } from '@testing-library/react';

import TeamPage from './page';

describe('TeamPage', () => {
  it('renders a placeholder heading so the nav link resolves', () => {
    render(<TeamPage />);
    expect(
      screen.getByRole('heading', { level: 1, name: 'The team' }),
    ).toBeTruthy();
  });
});
