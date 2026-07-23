import { fireEvent, render, screen, waitFor } from '@testing-library/react';

import { MagneticCta } from './magnetic-cta';

function mockMatchMedia(reduced: boolean) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: query === '(prefers-reduced-motion: reduce)' ? reduced : false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

function moveOverElement(el: Element) {
  jest.spyOn(el, 'getBoundingClientRect').mockReturnValue({
    width: 100,
    height: 40,
    top: 0,
    left: 0,
    right: 100,
    bottom: 40,
    x: 0,
    y: 0,
    toJSON: () => ({}),
  } as DOMRect);
  // `MagneticCta` tracks `mousemove`/`mouseleave` (not `pointermove`) —
  // jsdom has no native `PointerEvent` constructor, so `fireEvent.pointerMove`
  // silently produces an event with `clientX`/`clientY` both `undefined`,
  // which would make this assertion pass on a NaN transform. `MouseEvent`
  // is natively implemented in jsdom, so this exercises the real math.
  fireEvent.mouseMove(el, { clientX: 90, clientY: 36 });
}

describe('MagneticCta', () => {
  it('renders its children', () => {
    mockMatchMedia(false);
    render(
      <MagneticCta>
        <button type="button">Install</button>
      </MagneticCta>,
    );
    expect(screen.getByText('Install')).toBeTruthy();
  });

  it('pulls the wrapper toward the pointer on hover', async () => {
    mockMatchMedia(false);
    const { container } = render(
      <MagneticCta>
        <button type="button">Install</button>
      </MagneticCta>,
    );
    const wrapper = container.firstElementChild as HTMLElement;
    moveOverElement(wrapper);

    await waitFor(() => {
      expect(wrapper.style.transform).not.toBe('');
      expect(wrapper.style.transform).not.toContain('NaN');
      expect(wrapper.style.transform).not.toContain('translateX(0px)');
    });
  });

  it('pulls an anchor child (e.g. the Star-on-GitHub link) exactly like a button child', async () => {
    mockMatchMedia(false);
    const { container } = render(
      <MagneticCta>
        <a
          href="https://github.com/whimzyLive/nightshift-ai"
          target="_blank"
          rel="noopener"
        >
          ★ Star nightshift on GitHub
        </a>
      </MagneticCta>,
    );
    const wrapper = container.firstElementChild as HTMLElement;
    moveOverElement(wrapper);

    await waitFor(() => {
      expect(wrapper.style.transform).not.toBe('');
      expect(wrapper.style.transform).not.toContain('NaN');
      expect(wrapper.style.transform).not.toContain('translateX(0px)');
    });
  });

  it('releases back to rest on mouse-leave', async () => {
    mockMatchMedia(false);
    const { container } = render(
      <MagneticCta>
        <button type="button">Install</button>
      </MagneticCta>,
    );
    const wrapper = container.firstElementChild as HTMLElement;
    moveOverElement(wrapper);
    await waitFor(() =>
      expect(wrapper.style.transform).not.toContain('translateX(0px)'),
    );

    fireEvent.mouseLeave(wrapper);
    await waitFor(() => {
      expect(
        wrapper.style.transform === '' || wrapper.style.transform === 'none',
      ).toBe(true);
    });
  });

  it('stays static under reduced motion, ignoring pointer movement', async () => {
    mockMatchMedia(true);
    const { container } = render(
      <MagneticCta>
        <button type="button">Install</button>
      </MagneticCta>,
    );
    const wrapper = container.firstElementChild as HTMLElement;

    await waitFor(() => expect(wrapper).toBeTruthy());
    moveOverElement(wrapper);
    // Give any (unwanted) spring animation a chance to run before asserting.
    await new Promise((resolve) => setTimeout(resolve, 50));

    expect(
      wrapper.style.transform === '' || wrapper.style.transform === 'none',
    ).toBe(true);
  });
});
