import { render, screen } from '@testing-library/react';

import WhySdlcPage from './page';

describe('WhySdlcPage', () => {
  it('renders a placeholder heading so the nav link resolves', () => {
    render(<WhySdlcPage />);
    expect(
      screen.getByRole('heading', { level: 1, name: 'Why SDLC' }),
    ).toBeTruthy();
  });
});
