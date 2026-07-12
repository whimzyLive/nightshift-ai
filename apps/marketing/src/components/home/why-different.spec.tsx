import { render, screen } from '@testing-library/react';

import { WhyDifferent } from './why-different';

describe('WhyDifferent', () => {
  it('renders the four verbatim value card titles (AC4)', () => {
    render(<WhyDifferent />);
    expect(screen.getByText('The lifecycle is the product')).toBeTruthy();
    expect(screen.getByText('Generic agents, per-repo config')).toBeTruthy();
    expect(screen.getByText('Issue-tracker native')).toBeTruthy();
    expect(screen.getByText('Free, open, yours to fork')).toBeTruthy();
  });

  it('renders each card body verbatim', () => {
    const { container } = render(<WhyDifferent />);
    expect(container.textContent).toContain('Tests are the merge gate.');
    expect(container.textContent).toContain('project-context.md');
    expect(container.textContent).toContain(
      'comments the result back to Jira and GitHub.',
    );
    expect(container.textContent).toContain('MIT-licensed');
  });
});
