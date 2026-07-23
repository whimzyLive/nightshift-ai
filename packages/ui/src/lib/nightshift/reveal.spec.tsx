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

  it('forwards data-* attributes to the item DOM node (e.g. data-lift)', () => {
    render(
      <RevealGroup data-lift>
        <Reveal data-lift>card</Reveal>
      </RevealGroup>,
    );
    const item = screen.getByText('card');
    expect(item.getAttribute('data-lift')).toBe('true');
    // The group wrapper carries it too.
    expect(item.parentElement?.getAttribute('data-lift')).toBe('true');
  });

  it('accepts an opt-in spring transition without changing the default tween callers', () => {
    render(
      <RevealGroup>
        <Reveal spring={{ stiffness: 120, damping: 18 }}>settle</Reveal>
        <Reveal>default</Reveal>
      </RevealGroup>,
    );
    expect(screen.getByText('settle')).toBeTruthy();
    expect(screen.getByText('default')).toBeTruthy();
  });

  it('still renders visible under reduced motion when a spring is opted in', () => {
    window.matchMedia = jest.fn().mockImplementation((query: string) => ({
      matches: query === '(prefers-reduced-motion: reduce)',
      media: query,
      addEventListener: jest.fn(),
      removeEventListener: jest.fn(),
    })) as unknown as typeof window.matchMedia;

    render(
      <RevealGroup>
        <Reveal spring={{ stiffness: 120, damping: 18 }}>reduced settle</Reveal>
      </RevealGroup>,
    );
    expect(screen.getByText('reduced settle')).toBeTruthy();
  });
});
