import { fireEvent, render, screen } from '@testing-library/react';

import { FaqRow, type FaqAccordionItem } from './faq-row';

const ITEM: FaqAccordionItem = {
  id: 7,
  question: 'Does this ship on Motion?',
  answer: <p>Yes, everything animated is Motion now.</p>,
};

describe('FaqRow', () => {
  it('renders the Q.NN label, question, and answer', () => {
    render(
      <FaqRow
        index={3}
        item={ITEM}
        isOpen
        isLast={false}
        onToggle={jest.fn()}
      />,
    );
    expect(screen.getByText('Q.03')).toBeTruthy();
    expect(screen.getByText(ITEM.question)).toBeTruthy();
    expect(
      screen.getByText('Yes, everything animated is Motion now.'),
    ).toBeTruthy();
  });

  it('wires aria-expanded/aria-controls to the answer element id', () => {
    render(
      <FaqRow
        index={1}
        item={ITEM}
        isOpen
        isLast={false}
        onToggle={jest.fn()}
      />,
    );
    const toggle = screen.getByRole('button', {
      name: new RegExp(ITEM.question),
    });
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    const controlsId = toggle.getAttribute('aria-controls');
    expect(controlsId).toBe('faq-answer-7');
    expect(document.getElementById(controlsId ?? '')).not.toBeNull();
  });

  it('reflects isOpen=false as aria-expanded=false and a "+" glyph', () => {
    render(
      <FaqRow
        index={1}
        item={ITEM}
        isOpen={false}
        isLast={false}
        onToggle={jest.fn()}
      />,
    );
    const toggle = screen.getByRole('button', {
      name: new RegExp(ITEM.question),
    });
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(screen.getByText('+')).toBeTruthy();
  });

  it('calls onToggle when the row header is clicked', () => {
    const onToggle = jest.fn();
    render(
      <FaqRow
        index={1}
        item={ITEM}
        isOpen={false}
        isLast={false}
        onToggle={onToggle}
      />,
    );
    fireEvent.click(
      screen.getByRole('button', { name: new RegExp(ITEM.question) }),
    );
    expect(onToggle).toHaveBeenCalledTimes(1);
  });

  it('keeps the motion-reduce:transition-none class on the answer wrapper (external test contract)', () => {
    render(
      <FaqRow
        index={1}
        item={ITEM}
        isOpen
        isLast={false}
        onToggle={jest.fn()}
      />,
    );
    const toggle = screen.getByRole('button', {
      name: new RegExp(ITEM.question),
    });
    const answerPanel = document.getElementById(
      toggle.getAttribute('aria-controls') ?? '',
    );
    expect(answerPanel?.className).toContain('motion-reduce:transition-none');
  });
});
