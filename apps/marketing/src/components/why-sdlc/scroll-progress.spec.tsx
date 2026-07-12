import { render, screen } from '@testing-library/react';

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

  it('initialises reached to 5 and skips listeners under prefers-reduced-motion', () => {
    mockMatchMedia(true);
    const addSpy = jest.spyOn(window, 'addEventListener');
    render(
      <ScrollProgressProvider>
        <Probe />
      </ScrollProgressProvider>,
    );
    expect(screen.getByText('reached:5 active:0')).toBeTruthy();
    expect(addSpy).not.toHaveBeenCalledWith(
      'scroll',
      expect.any(Function),
      expect.anything(),
    );
    expect(addSpy).not.toHaveBeenCalledWith(
      'resize',
      expect.any(Function),
      expect.anything(),
    );
    addSpy.mockRestore();
  });

  it('removes scroll/resize listeners on unmount', () => {
    const removeSpy = jest.spyOn(window, 'removeEventListener');
    const { unmount } = render(
      <ScrollProgressProvider>
        <Probe />
      </ScrollProgressProvider>,
    );
    unmount();
    expect(removeSpy).toHaveBeenCalledWith('scroll', expect.any(Function));
    expect(removeSpy).toHaveBeenCalledWith('resize', expect.any(Function));
    removeSpy.mockRestore();
  });
});
