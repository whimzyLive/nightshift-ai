import { render, screen } from '@testing-library/react';

import { CtaKicker } from './cta-kicker';
import { useScrollProgress } from './scroll-progress';

jest.mock('./scroll-progress', () => ({ useScrollProgress: jest.fn() }));

const mockUseScrollProgress = useScrollProgress as jest.Mock;

describe('CtaKicker', () => {
  it('shows the dim "N of 5 gates ahead" copy while reached < 5', () => {
    mockUseScrollProgress.mockReturnValue({ reached: 2, active: 2 });
    render(<CtaKicker />);
    expect(
      screen.getByText('⊘ 3 of 5 gates ahead — the rail lights as you read'),
    ).toBeTruthy();
  });

  it('shows the green "all five gates passed" copy once reached >= 5', () => {
    mockUseScrollProgress.mockReturnValue({ reached: 5, active: 4 });
    render(<CtaKicker />);
    expect(
      screen.getByText(
        '✓ ✓ ✓ ✓ ✓ — all five gates passed. The argument survived your review.',
      ),
    ).toBeTruthy();
  });
});
