import { render } from '@testing-library/react';

import { CursorGlow } from './cursor-glow';

function mockMatchMedia(matches: Record<string, boolean>) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: matches[query] ?? false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

describe('CursorGlow', () => {
  it('renders nothing on a coarse (touch) pointer', () => {
    mockMatchMedia({
      '(pointer: fine)': false,
      '(prefers-reduced-motion: reduce)': false,
    });
    const { container } = render(<CursorGlow />);
    expect(container.firstChild).toBeNull();
  });

  it('renders nothing under prefers-reduced-motion', () => {
    mockMatchMedia({
      '(pointer: fine)': true,
      '(prefers-reduced-motion: reduce)': true,
    });
    const { container } = render(<CursorGlow />);
    expect(container.firstChild).toBeNull();
  });

  it('renders the glow element on a fine pointer with no reduced-motion preference', () => {
    mockMatchMedia({
      '(pointer: fine)': true,
      '(prefers-reduced-motion: reduce)': false,
    });
    const { container } = render(<CursorGlow />);
    expect(container.firstChild).not.toBeNull();
  });
});
