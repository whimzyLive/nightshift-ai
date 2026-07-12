import { render, screen } from '@testing-library/react';

import { Footer } from './footer';

describe('Footer', () => {
  it('renders the Plugin, Project, and Company columns', () => {
    render(<Footer />);
    expect(screen.getByText('Plugin')).toBeTruthy();
    expect(screen.getByText('Project')).toBeTruthy();
    expect(screen.getByText('Company')).toBeTruthy();
  });

  it('opens external links in a new tab with rel=noopener noreferrer', () => {
    render(<Footer />);
    const githubLink = screen.getByRole('link', { name: 'GitHub repo' });
    expect(githubLink.getAttribute('target')).toBe('_blank');
    expect(githubLink.getAttribute('rel')).toBe('noopener noreferrer');
  });

  it('keeps internal links as plain routes with no target attribute', () => {
    render(<Footer />);
    const teamLink = screen.getByRole('link', { name: 'The team' });
    expect(teamLink.getAttribute('href')).toBe('/team');
    expect(teamLink.getAttribute('target')).toBeNull();
  });
});
