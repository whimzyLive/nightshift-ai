import { render, screen, waitFor } from '@testing-library/react';

import Template from './template';

function mockMatchMedia(reduced: boolean) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: query === '(prefers-reduced-motion: reduce)' ? reduced : false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

describe('Template (D3 route enter transition)', () => {
  it('renders its children', () => {
    mockMatchMedia(false);
    render(
      <Template>
        <p>page content</p>
      </Template>,
    );
    expect(screen.getByText('page content')).toBeTruthy();
  });

  it('settles to fully visible whether or not reduced motion is set', async () => {
    mockMatchMedia(false);
    const { container } = render(
      <Template>
        <p>page content</p>
      </Template>,
    );
    await waitFor(() => {
      const wrapper = container.firstElementChild as HTMLElement;
      expect(wrapper.style.opacity).toBe('1');
    });
  });

  it('settles fully visible under reduced motion too, with no lingering transition', async () => {
    mockMatchMedia(true);
    const { container } = render(
      <Template>
        <p>page content</p>
      </Template>,
    );
    await waitFor(() => {
      const wrapper = container.firstElementChild as HTMLElement;
      expect(wrapper.style.opacity).toBe('1');
    });
    expect(screen.getByText('page content')).toBeTruthy();
  });

  it('never starts the enter animation under reduced motion — already visible on the very first synchronous render', () => {
    mockMatchMedia(true);
    const { container } = render(
      <Template>
        <p>page content</p>
      </Template>,
    );
    // No `waitFor` here on purpose: if reduced-motion were resolved via a
    // post-mount effect (the bug this guards against), the first render
    // would still commit `initial={{opacity:0,y:16}}` before the effect had
    // a chance to flip it, so this synchronous read would catch it at 0.
    const wrapper = container.firstElementChild as HTMLElement;
    expect(wrapper.style.opacity).toBe('1');
    expect(wrapper.style.transform || 'none').not.toMatch(/16px/);
  });

  it('does start from the faded/offset initial state when not reduced', () => {
    mockMatchMedia(false);
    const { container } = render(
      <Template>
        <p>page content</p>
      </Template>,
    );
    const wrapper = container.firstElementChild as HTMLElement;
    expect(wrapper.style.opacity).toBe('0');
  });
});
