import { render, screen } from '@testing-library/react';

import { Terminal } from './terminal';
import type { TerminalLine } from './terminal';

function mockMatchMedia(reduced: boolean) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: query === '(prefers-reduced-motion: reduce)' ? reduced : false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

const LINES: TerminalLine[] = [
  { prompt: '$', text: '/auto PROJ-142' },
  { text: 'Reading ticket…', tone: 'muted' },
  { text: '→ opened PR #318', tone: 'success' },
];

describe('Terminal', () => {
  it('renders the title and only line 1 on initial render (deterministic server frame)', () => {
    mockMatchMedia(false);
    render(<Terminal title="zsh — acme-api · claude code" lines={LINES} />);

    expect(screen.getByText('zsh — acme-api · claude code')).toBeTruthy();
    expect(screen.getByText('/auto PROJ-142')).toBeTruthy();
    expect(screen.queryByText('Reading ticket…')).toBeNull();
    expect(screen.queryByText('→ opened PR #318')).toBeNull();
  });

  it('renders all lines immediately with no reveal timer under reduced motion', () => {
    mockMatchMedia(true);
    const setIntervalSpy = jest.spyOn(window, 'setInterval');

    render(<Terminal title="zsh — acme-api · claude code" lines={LINES} />);

    expect(screen.getByText('/auto PROJ-142')).toBeTruthy();
    expect(screen.getByText('Reading ticket…')).toBeTruthy();
    expect(screen.getByText('→ opened PR #318')).toBeTruthy();
    expect(setIntervalSpy).not.toHaveBeenCalled();

    setIntervalSpy.mockRestore();
  });
});
