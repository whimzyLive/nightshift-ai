import { render, screen } from '@testing-library/react';

import { Reveal, RevealGroup } from './reveal';

describe('Reveal', () => {
  it('renders its group and item children', () => {
    render(
      <RevealGroup>
        <Reveal>first</Reveal>
        <Reveal as="p">second</Reveal>
      </RevealGroup>,
    );
    expect(screen.getByText('first')).toBeTruthy();
    expect(screen.getByText('second')).toBeTruthy();
  });

  it('honours the requested element tag', () => {
    render(
      <RevealGroup>
        <Reveal as="h2">heading</Reveal>
      </RevealGroup>,
    );
    expect(screen.getByText('heading').tagName).toBe('H2');
  });

  it('passes through className and style to the item', () => {
    render(
      <RevealGroup>
        <Reveal className="marker" style={{ color: 'rgb(1, 2, 3)' }}>
          styled
        </Reveal>
      </RevealGroup>,
    );
    const el = screen.getByText('styled');
    expect(el.className).toContain('marker');
    expect(el.style.color).toBe('rgb(1, 2, 3)');
  });
});
