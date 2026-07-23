import { render } from '@testing-library/react';

import { GateCheck } from './gate-check';

describe('GateCheck', () => {
  it('renders an inline check-mark svg', () => {
    const { container } = render(<GateCheck />);
    const svg = container.querySelector('svg');
    const path = container.querySelector('path');
    expect(svg).toBeTruthy();
    expect(path).toBeTruthy();
    expect(path?.getAttribute('stroke')).toBe('var(--success)');
  });

  it('is aria-hidden with no accessible name by default', () => {
    const { container } = render(<GateCheck />);
    const svg = container.querySelector('svg');
    expect(svg?.getAttribute('aria-hidden')).toBe('true');
    expect(svg?.getAttribute('role')).toBeNull();
  });

  it('exposes an accessible label instead of aria-hidden when one is passed', () => {
    const { container } = render(<GateCheck label="passed" />);
    const svg = container.querySelector('svg');
    expect(svg?.getAttribute('aria-hidden')).toBeNull();
    expect(svg?.getAttribute('role')).toBe('img');
    expect(svg?.getAttribute('aria-label')).toBe('passed');
  });

  it('renders fully drawn immediately under reduced motion', () => {
    const { container } = render(<GateCheck reduced />);
    const path = container.querySelector('path');
    expect(path?.getAttribute('stroke-dasharray')).toBe('1 1');
  });

  it('starts undrawn (pathLength 0) when not reduced, drawing in from there', () => {
    const { container } = render(<GateCheck />);
    const path = container.querySelector('path');
    expect(path?.getAttribute('stroke-dasharray')).toBe('0 1');
  });

  it('uses the requested size and colour', () => {
    const { container } = render(
      <GateCheck size={24} color="var(--terra-400)" />,
    );
    const svg = container.querySelector('svg');
    const path = container.querySelector('path');
    expect(svg?.getAttribute('width')).toBe('24');
    expect(svg?.getAttribute('height')).toBe('24');
    expect(path?.getAttribute('stroke')).toBe('var(--terra-400)');
  });
});
