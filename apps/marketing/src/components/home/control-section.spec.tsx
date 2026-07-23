import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';

import { ControlSection } from './control-section';

function mockMatchMedia(reduced: boolean) {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: query === '(prefers-reduced-motion: reduce)' ? reduced : false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

describe('ControlSection', () => {
  beforeEach(() => {
    mockMatchMedia(false);
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('renders the header copy verbatim', () => {
    render(<ControlSection />);
    expect(screen.getByText('You decide how it gets built')).toBeTruthy();
  });

  describe('_route derivation (AC2)', () => {
    it('defaults to full ceremony — 5 gates (default story, 8 pts > threshold 3)', () => {
      render(<ControlSection />);
      expect(screen.getByText('refine')).toBeTruthy();
      expect(screen.getByText('spec')).toBeTruthy();
      expect(screen.getByText('plan')).toBeTruthy();
      expect(screen.getByText('implement')).toBeTruthy();
      expect(screen.getByText('review')).toBeTruthy();
    });

    it('routes bugs to the defect route — 2 gates', () => {
      render(<ControlSection />);
      fireEvent.click(screen.getByText('bug'));
      expect(screen.getByText('implement')).toBeTruthy();
      expect(screen.getByText('review')).toBeTruthy();
      expect(screen.queryByText('refine')).toBeNull();
      expect(screen.queryByText('spec')).toBeNull();
      expect(screen.queryByText('plan')).toBeNull();
    });

    it('routes a story at/under threshold to lightweight — 3 gates', () => {
      render(<ControlSection />);
      const incBtn = screen.getByRole('button', {
        name: 'increase lightweight threshold',
      });
      // default storyPts 8, thresh 3 — bump threshold to 8 so 8 <= 8.
      for (let i = 0; i < 5; i++) fireEvent.click(incBtn);
      expect(screen.getByText('refine')).toBeTruthy();
      expect(screen.getByText('implement')).toBeTruthy();
      expect(screen.getByText('review')).toBeTruthy();
      expect(screen.queryByText('spec')).toBeNull();
      expect(screen.queryByText('plan')).toBeNull();
    });
  });

  it('AC4: a config change re-syncs triage lanes, gate count, and the right-terminal route name together, and restarts the gate walk at gate 0', () => {
    render(<ControlSection />);
    expect(screen.getByText(/🌙 nightshift · full ceremony/)).toBeTruthy();

    const incBtn = screen.getByRole('button', {
      name: 'increase lightweight threshold',
    });
    for (let i = 0; i < 5; i++) fireEvent.click(incBtn);

    // Route flips to lightweight everywhere at once — gate strip, right
    // terminal label, and the gate walk all agree.
    expect(screen.getByText(/🌙 nightshift · lightweight route/)).toBeTruthy();
    expect(screen.queryByText('spec')).toBeNull();
    expect(screen.queryByText('plan')).toBeNull();
    // Gate walk restarted at gate 0 — 'refine' is working again.
    expect(screen.getByText(/refining PROJ-142/)).toBeTruthy();
  });

  it('threshold stepper clamps at 1 and 8 — buttons no-op at bounds', () => {
    render(<ControlSection />);
    const decBtn = screen.getByRole('button', {
      name: 'decrease lightweight threshold',
    });
    const incBtn = screen.getByRole('button', {
      name: 'increase lightweight threshold',
    });
    // The threshold value sits between the two stepper buttons in the DOM.
    const thresholdValue = () => decBtn.nextElementSibling?.textContent;

    for (let i = 0; i < 10; i++) fireEvent.click(decBtn);
    expect(thresholdValue()).toBe('1');

    for (let i = 0; i < 10; i++) fireEvent.click(incBtn);
    expect(thresholdValue()).toBe('8');
  });

  it('approveGate no-op guard: the approve control only appears once the current gate is awaiting, and advances exactly one gate per click', () => {
    jest.useFakeTimers();
    render(<ControlSection />);

    // Still 'working' at mount — no approve control yet, guard holds.
    expect(screen.queryByRole('button', { name: 'approve ✓' })).toBeNull();

    act(() => {
      jest.advanceTimersByTime(1700);
    });

    const approveBtn = screen.getByRole('button', { name: 'approve ✓' });
    act(() => {
      fireEvent.click(approveBtn);
    });

    // Advanced past 'refine' onto 'spec', back to 'working' — approve gone.
    expect(screen.queryByRole('button', { name: 'approve ✓' })).toBeNull();
  });

  describe('B3 tap-scale (whileTap)', () => {
    it('scales the threshold stepper down on pointer press and releases on pointer up', async () => {
      render(<ControlSection />);
      const incBtn = screen.getByRole('button', {
        name: 'increase lightweight threshold',
      });

      fireEvent.pointerDown(incBtn);
      await waitFor(
        () => {
          expect(incBtn.style.transform).toContain('scale');
        },
        { timeout: 3000 },
      );

      fireEvent.pointerUp(incBtn);
      await waitFor(
        () => {
          expect(incBtn.style.transform).not.toContain('scale');
        },
        { timeout: 3000 },
      );
    });

    it('omits the tap scale under reduced motion', async () => {
      mockMatchMedia(true);
      render(<ControlSection />);
      const incBtn = screen.getByRole('button', {
        name: 'increase lightweight threshold',
      });

      fireEvent.pointerDown(incBtn);
      // Give any (unwanted) tap animation a chance to apply before asserting.
      await new Promise((resolve) => setTimeout(resolve, 50));
      expect(incBtn.style.transform).not.toContain('scale');
    });
  });

  describe('reduced motion (AC5)', () => {
    it('jumps the one-shot terminal straight to its final failure line, and the current gate reaches awaiting quickly', () => {
      mockMatchMedia(true);
      jest.useFakeTimers();
      const { container } = render(<ControlSection />);

      expect(container.textContent).toContain(
        '❓ built the wrong thing. read all 4,213 lines to find out where.',
      );

      act(() => {
        jest.advanceTimersByTime(400);
      });
      expect(screen.getByRole('button', { name: 'approve ✓' })).toBeTruthy();
    });
  });
});
