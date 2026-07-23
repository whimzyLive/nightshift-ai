import { render, screen } from '@testing-library/react';

import Template from './template';

describe('Template (D3 route enter transition)', () => {
  it('renders children inside the CSS-driven enter-fade wrapper', () => {
    const { container } = render(
      <Template>
        <p>page content</p>
      </Template>,
    );
    expect(screen.getByText('page content')).toBeTruthy();
    const wrapper = container.firstElementChild as HTMLElement;
    expect(wrapper.className).toContain('ns-route-enter');
  });

  it('applies no transform — opacity-only, so it never becomes a containing block for fixed-position descendants (e.g. NightSky)', () => {
    const { container } = render(
      <Template>
        <p>page content</p>
      </Template>,
    );
    const wrapper = container.firstElementChild as HTMLElement;
    expect(wrapper.style.transform).toBe('');
    expect(wrapper.style.opacity).toBe('');
  });

  it('never reads matchMedia during render — the CSS keyframe is neutralized by the global reduced-motion media query instead', () => {
    const matchMediaSpy = jest.fn();
    window.matchMedia = matchMediaSpy as unknown as typeof window.matchMedia;

    render(
      <Template>
        <p>page content</p>
      </Template>,
    );

    expect(matchMediaSpy).not.toHaveBeenCalled();
  });
});
