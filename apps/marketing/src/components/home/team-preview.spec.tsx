import {
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from '@testing-library/react';

import { TeamPreview } from './team-preview';

function rowFor(label: string): HTMLElement {
  const row = screen.getByText(label).closest('div');
  if (!row) throw new Error(`row for "${label}" not found`);
  return row;
}

function mockMatchMedia(reduced: boolean) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: query === '(prefers-reduced-motion: reduce)' ? reduced : false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
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

  it('updates the side panel and dims other rows on hover (AC3)', async () => {
    const { container } = render(<TeamPreview />);
    const row = rowFor('product-manager');
    fireEvent.mouseEnter(row);

    // The panel body now crossfades via AnimatePresence (A3) — its new
    // content lands once the (near-instant) exit/enter transition settles.
    await waitFor(() =>
      expect(container.textContent).toContain(
        'Vague idea → PRD with binary acceptance criteria',
      ),
    );
    expect(rowFor('qa-engineer').getAttribute('style')).toContain(
      'opacity: 0.45',
    );
    expect(row.getAttribute('style')).toContain('opacity: 1');
  });

  it('restores the org summary and full opacity when the tree loses hover (AC3)', async () => {
    const { container } = render(<TeamPreview />);
    fireEvent.mouseEnter(rowFor('product-manager'));

    const treeContainer = container.querySelector('#ns-org');
    if (!treeContainer) throw new Error('#ns-org tree container not found');
    fireEvent.mouseLeave(treeContainer);

    await waitFor(() =>
      expect(container.textContent).toContain('1 human · 11 agents'),
    );
    expect(rowFor('qa-engineer').getAttribute('style')).toContain('opacity: 1');
  });

  it('links to the in-app /team route, not the raw design HTML (AC3)', () => {
    render(<TeamPreview />);
    const link = screen.getByRole('link', { name: /meet the whole team/i });
    expect(link.getAttribute('href')).toBe('/team');
  });

  it('gates the tree twinkle animation behind a direct matchMedia check (AC5)', async () => {
    mockMatchMedia(false);
    render(<TeamPreview />);
    const row = rowFor('product-manager');
    const dot = await within(row).findByTestId('team-dot');
    expect(dot.getAttribute('data-twinkle')).toBe('on');
  });

  it('freezes the tree twinkle animation under reduced motion (AC5)', async () => {
    mockMatchMedia(true);
    render(<TeamPreview />);
    const row = rowFor('product-manager');
    const dot = await within(row).findByTestId('team-dot');
    expect(dot.getAttribute('data-twinkle')).toBe('off');
  });

  describe('A3 dot→charter shared-element morph', () => {
    it('renders a matching panel dot only for a star row (agent), not a phase row', async () => {
      const { queryByTestId } = render(<TeamPreview />);

      fireEvent.mouseEnter(rowFor('product-manager'));
      await waitFor(() => expect(queryByTestId('panel-dot')).toBeTruthy());

      fireEvent.mouseEnter(rowFor('spec'));
      await waitFor(() => expect(queryByTestId('panel-dot')).toBeNull());
    });

    it('still updates the panel on hover under reduced motion, without the layout morph', async () => {
      mockMatchMedia(true);
      const { container, queryByTestId } = render(<TeamPreview />);

      fireEvent.mouseEnter(rowFor('product-manager'));

      await waitFor(() =>
        expect(container.textContent).toContain(
          'Vague idea → PRD with binary acceptance criteria',
        ),
      );
      // The dot still renders (star row) — just without a layoutId driving
      // a morph, which isn't independently observable via the DOM, so this
      // asserts the functional outcome (panel dot present, content correct)
      // rather than the absence of an internal Framer prop.
      expect(queryByTestId('panel-dot')).toBeTruthy();
    });

    it('never mounts the tree-row dot and the panel dot with the same layoutId at once (no Framer duplicate-layoutId warning)', async () => {
      mockMatchMedia(false);
      const warnSpy = jest.spyOn(console, 'warn').mockImplementation();
      const errorSpy = jest.spyOn(console, 'error').mockImplementation();

      const { queryByTestId } = render(<TeamPreview />);
      fireEvent.mouseEnter(rowFor('product-manager'));
      await waitFor(() => expect(queryByTestId('panel-dot')).toBeTruthy());

      const duplicateLayoutIdCalls = [
        ...warnSpy.mock.calls,
        ...errorSpy.mock.calls,
      ].filter((call) => String(call[0]).toLowerCase().includes('layoutid'));
      expect(duplicateLayoutIdCalls).toHaveLength(0);

      warnSpy.mockRestore();
      errorSpy.mockRestore();
    });
  });

  describe('D2 draggable agent constellation', () => {
    it('stays hidden until the reveal trigger is hovered or focused', () => {
      mockMatchMedia(false);
      const { getByRole, queryByTestId } = render(<TeamPreview />);
      expect(queryByTestId('agent-constellation')).toBeNull();

      const trigger = getByRole('button', {
        name: 'Reveal the agent constellation',
      });
      fireEvent.mouseEnter(trigger.parentElement as HTMLElement);
      expect(queryByTestId('agent-constellation')).toBeTruthy();
    });

    it('hides again once the pointer leaves', () => {
      mockMatchMedia(false);
      const { getByRole, queryByTestId } = render(<TeamPreview />);
      const trigger = getByRole('button', {
        name: 'Reveal the agent constellation',
      });
      const wrapper = trigger.parentElement as HTMLElement;

      fireEvent.mouseEnter(wrapper);
      expect(queryByTestId('agent-constellation')).toBeTruthy();

      fireEvent.mouseLeave(wrapper);
      expect(queryByTestId('agent-constellation')).toBeNull();
    });

    it('is keyboard-discoverable via tab focus, not just hover', () => {
      mockMatchMedia(false);
      const { getByRole, queryByTestId } = render(<TeamPreview />);
      const trigger = getByRole('button', {
        name: 'Reveal the agent constellation',
      });

      fireEvent.focus(trigger);
      expect(queryByTestId('agent-constellation')).toBeTruthy();

      fireEvent.blur(trigger);
      expect(queryByTestId('agent-constellation')).toBeNull();
    });

    it('renders all 11 agents as star nodes once revealed', () => {
      mockMatchMedia(false);
      const { getByRole, getAllByTestId } = render(<TeamPreview />);
      fireEvent.focus(
        getByRole('button', { name: 'Reveal the agent constellation' }),
      );
      expect(getAllByTestId('constellation-star')).toHaveLength(11);
    });

    it('disables the drag affordance under reduced motion (cursor stays default, not grab)', () => {
      mockMatchMedia(true);
      const { getByRole, getAllByTestId } = render(<TeamPreview />);
      fireEvent.focus(
        getByRole('button', { name: 'Reveal the agent constellation' }),
      );
      const stars = getAllByTestId('constellation-star');
      expect(stars.every((s) => s.style.cursor === 'default')).toBe(true);
    });

    it('offers a grab cursor when not reduced (drag enabled)', () => {
      mockMatchMedia(false);
      const { getByRole, getAllByTestId } = render(<TeamPreview />);
      fireEvent.focus(
        getByRole('button', { name: 'Reveal the agent constellation' }),
      );
      const stars = getAllByTestId('constellation-star');
      expect(stars.every((s) => s.style.cursor === 'grab')).toBe(true);
    });
  });
});
