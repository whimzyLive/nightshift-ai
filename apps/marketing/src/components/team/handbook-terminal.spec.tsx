import { render, screen } from '@testing-library/react';

import { HandbookTerminal } from './handbook-terminal';

describe('HandbookTerminal', () => {
  it('renders all six handbook steps', () => {
    render(<HandbookTerminal />);
    expect(
      screen.getAllByText(/./, { selector: 'li' }).length,
    ).toBeGreaterThanOrEqual(6);
    expect(
      screen.getByText(/\.claude\/project\/agents\/<you>\.md/),
    ).toBeTruthy();
  });
});
