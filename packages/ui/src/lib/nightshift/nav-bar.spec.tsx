import { render, screen } from '@testing-library/react';

import { isActiveLink, NavBar } from './nav-bar';

const mockUsePathname = jest.fn();

jest.mock('next/navigation', () => ({
  usePathname: () => mockUsePathname(),
}));

describe('isActiveLink', () => {
  it('treats an in-page anchor link as active only on the home route', () => {
    expect(isActiveLink('/', '/#how-it-works')).toBe(true);
    expect(isActiveLink('/faq', '/#how-it-works')).toBe(false);
  });

  it('matches a plain route link by exact pathname', () => {
    expect(isActiveLink('/why-sdlc', '/why-sdlc')).toBe(true);
    expect(isActiveLink('/team', '/why-sdlc')).toBe(false);
  });
});

describe('NavBar', () => {
  beforeEach(() => {
    mockUsePathname.mockReturnValue('/why-sdlc');
  });

  it('renders exactly 5 nav links plus 1 primary CTA', () => {
    render(<NavBar />);
    const links = screen.getAllByRole('link');
    // 5 nav links (How it works, Why SDLC, The team, FAQ, GitHub) + logo link + CTA link = 7
    const labels = links.map((l) => l.textContent);
    expect(labels).toEqual(
      expect.arrayContaining([
        'How it works',
        'Why SDLC',
        'The team',
        'FAQ',
        'GitHub',
        'Install the plugin',
      ]),
    );
  });

  it('marks the current route link active and others not', () => {
    render(<NavBar />);
    const activeLink = screen.getByRole('link', { name: 'Why SDLC' });
    const inactiveLink = screen.getByRole('link', { name: 'FAQ' });
    expect(activeLink.getAttribute('aria-current')).toBe('page');
    expect(inactiveLink.getAttribute('aria-current')).toBeNull();
  });

  it('opens the GitHub link in a new tab safely', () => {
    render(<NavBar />);
    const githubLink = screen.getByRole('link', { name: 'GitHub' });
    expect(githubLink.getAttribute('href')).toBe(
      'https://github.com/whimzyLive/nightshift-ai',
    );
    expect(githubLink.getAttribute('target')).toBe('_blank');
    expect(githubLink.getAttribute('rel')).toBe('noopener noreferrer');
  });
});
