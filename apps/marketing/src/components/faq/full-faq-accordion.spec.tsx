import { fireEvent, render, screen } from '@testing-library/react';

import {
  FullFaqAccordion,
  type FullFaqAccordionGroup,
} from './full-faq-accordion';

const groups: FullFaqAccordionGroup[] = [
  {
    key: 'positioning',
    eyebrow: '// positioning',
    items: [
      { id: 1, number: 1, question: 'Q one?', answer: <p>Answer one</p> },
      { id: 2, number: 2, question: 'Q two?', answer: <p>Answer two</p> },
    ],
  },
  {
    key: 'workflow-control',
    eyebrow: '// workflow & control',
    items: [
      { id: 3, number: 3, question: 'Q three?', answer: <p>Answer three</p> },
    ],
  },
];

describe('FullFaqAccordion', () => {
  it('renders every group eyebrow and every question with continuous Q.NN numbers', () => {
    render(<FullFaqAccordion groups={groups} />);
    expect(screen.getByText('// positioning')).toBeTruthy();
    expect(screen.getByText('// workflow & control')).toBeTruthy();
    expect(screen.getByText('Q one?')).toBeTruthy();
    expect(screen.getByText('Q three?')).toBeTruthy();
    expect(screen.getByText(/Q\.01/)).toBeTruthy();
    expect(screen.getByText(/Q\.03/)).toBeTruthy(); // continuous across group boundary
  });

  it('starts fully collapsed', () => {
    render(<FullFaqAccordion groups={groups} />);
    screen
      .getAllByRole('button')
      .forEach((btn) =>
        expect(btn.getAttribute('aria-expanded')).toBe('false'),
      );
  });

  it('opens a row on click', () => {
    render(<FullFaqAccordion groups={groups} />);
    const btn = screen.getByRole('button', { name: /Q one\?/ });
    fireEvent.click(btn);
    expect(btn.getAttribute('aria-expanded')).toBe('true');
  });

  it('opening a row in another group closes the previously open row (single-open across page)', () => {
    render(<FullFaqAccordion groups={groups} />);
    const first = screen.getByRole('button', { name: /Q one\?/ });
    const otherGroup = screen.getByRole('button', { name: /Q three\?/ });
    fireEvent.click(first);
    fireEvent.click(otherGroup);
    expect(first.getAttribute('aria-expanded')).toBe('false');
    expect(otherGroup.getAttribute('aria-expanded')).toBe('true');
  });

  it('clicking the open row closes it', () => {
    render(<FullFaqAccordion groups={groups} />);
    const btn = screen.getByRole('button', { name: /Q two\?/ });
    fireEvent.click(btn);
    fireEvent.click(btn);
    expect(btn.getAttribute('aria-expanded')).toBe('false');
  });
});
