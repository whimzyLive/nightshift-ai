import { render, screen } from '@testing-library/react';

import { HowItWorks } from './how-it-works';

describe('HowItWorks', () => {
  it('renders the /auto PROJ-142 install snippet', () => {
    const { container } = render(<HowItWorks />);
    expect(container.textContent).toContain('/auto PROJ-142');
  });

  it('renders the 5-step table', () => {
    render(<HowItWorks />);
    expect(screen.getByText('PRD + spec')).toBeTruthy();
    expect(screen.getByText('The ticket becomes a written spec')).toBeTruthy();
    expect(screen.getByText('PR + ticket comment')).toBeTruthy();
    expect(
      screen.getByText(
        'A reviewed PR, with the paper trail linked back to the ticket',
      ),
    ).toBeTruthy();
  });

  it('renders the lightweight fast-path note (AC1)', () => {
    const { container } = render(<HowItWorks />);
    expect(container.textContent).toContain('/auto');
    expect(container.textContent).toContain('triages by size');
    expect(container.textContent).toContain('lightweight threshold');
    expect(container.textContent).toContain(
      'skip the spec and plan and go straight to implementation',
    );
  });

  it('renders the drive-a-stage note with verb tokens (AC1)', () => {
    const { container } = render(<HowItWorks />);
    expect(container.textContent).toContain('Drive a stage yourself.');
    expect(container.textContent).toContain('/spec');
    expect(container.textContent).toContain('/plan');
    expect(container.textContent).toContain('/impl');
    expect(container.textContent).toContain('/review');
  });

  it('renders the conventional-commit example terminal (C3)', () => {
    const { container } = render(<HowItWorks />);
    expect(container.textContent).toContain('git log -1 --oneline');
    expect(container.textContent).toContain('zsh — conventional commits');
  });

  it('links to the commands on GitHub', () => {
    render(<HowItWorks />);
    const link = screen.getByRole('link', {
      name: /see the commands on github/i,
    });
    expect(link.getAttribute('href')).toBe(
      'https://github.com/whimzyLive/nightshift-ai',
    );
    expect(link.getAttribute('target')).toBe('_blank');
    expect(link.getAttribute('rel')).toBe('noopener');
  });
});
