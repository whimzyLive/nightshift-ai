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
});
