import { fireEvent, render, screen } from '@testing-library/react';

import { FaqAccordion } from './faq-accordion';

const ITEMS = [
  { id: 1, question: 'Isn’t this just another wrapper?', answer: <p>No.</p> },
  { id: 2, question: 'Full ceremony is overkill?', answer: <p>Depends.</p> },
  { id: 3, question: 'What does it cost?', answer: <p>Nothing.</p> },
];

describe('FaqAccordion', () => {
  it('renders every question and a numbered Q.0N label', () => {
    render(<FaqAccordion items={ITEMS} />);
    expect(screen.getByText(ITEMS[0].question)).toBeTruthy();
    expect(screen.getByText(ITEMS[1].question)).toBeTruthy();
    expect(screen.getByText(ITEMS[2].question)).toBeTruthy();
    expect(screen.getByText('Q.01')).toBeTruthy();
    expect(screen.getByText('Q.02')).toBeTruthy();
    expect(screen.getByText('Q.03')).toBeTruthy();
  });

  it('opens the first entry by default, with its answer visible and aria-expanded true', () => {
    render(<FaqAccordion items={ITEMS} />);
    const firstToggle = screen.getByRole('button', {
      name: new RegExp(ITEMS[0].question),
    });
    expect(firstToggle.getAttribute('aria-expanded')).toBe('true');
    expect(screen.getByText('No.')).toBeTruthy();
  });

  it('closes the previously-open entry when a different one is opened — only one open at a time', () => {
    render(<FaqAccordion items={ITEMS} />);
    const secondToggle = screen.getByRole('button', {
      name: new RegExp(ITEMS[1].question),
    });
    fireEvent.click(secondToggle);

    const firstToggle = screen.getByRole('button', {
      name: new RegExp(ITEMS[0].question),
    });
    expect(firstToggle.getAttribute('aria-expanded')).toBe('false');
    expect(secondToggle.getAttribute('aria-expanded')).toBe('true');
  });

  it('closes an open entry when its own toggle is clicked again', () => {
    render(<FaqAccordion items={ITEMS} />);
    const firstToggle = screen.getByRole('button', {
      name: new RegExp(ITEMS[0].question),
    });
    fireEvent.click(firstToggle);
    expect(firstToggle.getAttribute('aria-expanded')).toBe('false');
  });

  it('shows a "+" glyph when closed and a "−" glyph when open', () => {
    render(<FaqAccordion items={ITEMS} />);
    // item 0 is open by default
    expect(screen.getByText('−')).toBeTruthy();
    expect(screen.getAllByText('+')).toHaveLength(2);
  });

  it('gates the max-height/opacity transition behind motion-reduce (AC4)', () => {
    render(<FaqAccordion items={ITEMS} />);
    const firstToggle = screen.getByRole('button', {
      name: new RegExp(ITEMS[0].question),
    });
    const answerPanel = document.getElementById(
      firstToggle.getAttribute('aria-controls') ?? '',
    );
    expect(answerPanel?.className).toContain('motion-reduce:transition-none');
  });
});
