import { render, screen } from '@testing-library/react';

import { DayNightWorkflow } from './day-night-workflow';

describe('DayNightWorkflow', () => {
  it('renders the #workflow deep-link anchor (AC2)', () => {
    const { container } = render(<DayNightWorkflow />);
    expect(container.querySelector('#workflow')).toBeTruthy();
  });

  it('renders the day, night, and morning cards', () => {
    render(<DayNightWorkflow />);
    expect(screen.getByText('You refine')).toBeTruthy();
    expect(screen.getByText('The plugin implements')).toBeTruthy();
    expect(screen.getByText('You review')).toBeTruthy();
  });

  it('visibly accent-rings the night card (AC2)', () => {
    render(<DayNightWorkflow />);
    const nightHeading = screen.getByText('The plugin implements');
    const card = nightHeading.closest('div');
    const style = card?.getAttribute('style') ?? '';
    expect(style).toContain('var(--border-accent)');
    expect(style).toContain('var(--glow-accent)');
  });

  it('renders the closing paragraph verbs', () => {
    const { container } = render(<DayNightWorkflow />);
    expect(container.textContent).toContain('/refine-issue');
    expect(container.textContent).toContain('/spec');
    expect(container.textContent).toContain('/impl');
    expect(container.textContent).toContain('/review');
  });
});
