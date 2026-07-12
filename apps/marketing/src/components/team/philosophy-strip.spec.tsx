import { render, screen } from '@testing-library/react';

import { PhilosophyStrip } from './philosophy-strip';
import { PHILOSOPHY } from './roster-data';

describe('PhilosophyStrip', () => {
  it('renders all four philosophy cards', () => {
    render(<PhilosophyStrip />);
    for (const card of PHILOSOPHY) {
      expect(screen.getByText(card.title)).toBeTruthy();
    }
  });
});
