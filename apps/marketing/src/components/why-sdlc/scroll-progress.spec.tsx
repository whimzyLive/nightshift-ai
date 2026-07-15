import { fireEvent, render, screen } from '@testing-library/react';

import { ScrollProgressProvider, useScrollProgress } from './scroll-progress';

function mockMatchMedia(reduced: boolean) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: reduced,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

function Probe() {
  const { reached, active } = useScrollProgress();
  return <span>{`reached:${reached} active:${active}`}</span>;
}

describe('ScrollProgressProvider / useScrollProgress', () => {
  beforeEach(() => {
    mockMatchMedia(false);
  });

  it('mounts its children', () => {
    render(
      <ScrollProgressProvider>
        <span>child content</span>
      </ScrollProgressProvider>,
    );
    expect(screen.getByText('child content')).toBeTruthy();
  });

  it('defaults to { reached: 0, active: 0 }', () => {
    render(
      <ScrollProgressProvider>
        <Probe />
      </ScrollProgressProvider>,
    );
    expect(screen.getByText('reached:0 active:0')).toBeTruthy();
  });

  it('initialises reached to 5 under prefers-reduced-motion and never derives from scroll again', () => {
    mockMatchMedia(true);
    render(
      <ScrollProgressProvider>
        <Probe />
      </ScrollProgressProvider>,
    );
    expect(screen.getByText('reached:5 active:0')).toBeTruthy();
    // A resize (which would otherwise re-derive from `[data-why-sec]`
    // positions) must stay a no-op once reduced-motion has been latched.
    fireEvent(window, new Event('resize'));
    expect(screen.getByText('reached:5 active:0')).toBeTruthy();
  });

  it('removes its resize listener on unmount', () => {
    // Motion's `useScroll` owns the `scroll` listener internally — this
    // provider only manages its own `resize` listener directly.
    const removeSpy = jest.spyOn(window, 'removeEventListener');
    const { unmount } = render(
      <ScrollProgressProvider>
        <Probe />
      </ScrollProgressProvider>,
    );
    unmount();
    expect(removeSpy).toHaveBeenCalledWith('resize', expect.any(Function));
    removeSpy.mockRestore();
  });
});
