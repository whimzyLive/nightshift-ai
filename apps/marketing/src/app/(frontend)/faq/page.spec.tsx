import { render, screen } from '@testing-library/react';

import FaqPage from './page';

describe('FaqPage', () => {
  it('renders a placeholder heading so the nav link resolves', () => {
    render(<FaqPage />);
    expect(screen.getByRole('heading', { level: 1, name: 'FAQ' })).toBeTruthy();
  });
});
