import { fireEvent, render, screen } from '@testing-library/react';

import { TeamPreview } from './team-preview';

function rowFor(label: string): HTMLElement {
  const row = screen.getByText(label).closest('div');
  if (!row) throw new Error(`row for "${label}" not found`);
  return row;
}

describe('TeamPreview', () => {
  it('renders the box-drawing tree prompt', () => {
    const { container } = render(<TeamPreview />);
    expect(container.textContent).toContain('nightshift --team --tree');
  });

  it('shows the org summary by default, fully legible with no hover (AC5)', () => {
    const { container } = render(<TeamPreview />);
    expect(container.textContent).toContain('1 human · 11 agents');
    expect(rowFor('product-manager').getAttribute('style')).toContain(
      'opacity: 1',
    );
  });

  it('updates the side panel and dims other rows on hover (AC3)', () => {
    const { container } = render(<TeamPreview />);
    const row = rowFor('product-manager');
    fireEvent.mouseEnter(row);

    expect(container.textContent).toContain(
      'Vague idea → PRD with binary acceptance criteria',
    );
    expect(rowFor('qa-engineer').getAttribute('style')).toContain(
      'opacity: 0.45',
    );
    expect(row.getAttribute('style')).toContain('opacity: 1');
  });

  it('restores the org summary and full opacity when the tree loses hover (AC3)', () => {
    const { container } = render(<TeamPreview />);
    fireEvent.mouseEnter(rowFor('product-manager'));

    const treeContainer = container.querySelector('#ns-org');
    if (!treeContainer) throw new Error('#ns-org tree container not found');
    fireEvent.mouseLeave(treeContainer);

    expect(container.textContent).toContain('1 human · 11 agents');
    expect(rowFor('qa-engineer').getAttribute('style')).toContain('opacity: 1');
  });

  it('links to the in-app /team route, not the raw design HTML (AC3)', () => {
    render(<TeamPreview />);
    const link = screen.getByRole('link', { name: /meet the whole team/i });
    expect(link.getAttribute('href')).toBe('/team');
  });

  it('gates the tree twinkle animation behind motion-safe (AC5)', () => {
    render(<TeamPreview />);
    const row = rowFor('product-manager');
    const dot = row.querySelector('[class*="motion-safe:animate"]');
    expect(dot).toBeTruthy();
  });
});
