import { render, screen, fireEvent } from '@testing-library/react';
import { SiteHeader } from './SiteHeader';

it('renders an empty state when siteSettings is undefined', () => {
  expect(() => render(<SiteHeader siteSettings={undefined} />)).not.toThrow();
});

it('renders the CMS-sourced githubLabel on the GitHub button', () => {
  render(
    <SiteHeader
      siteSettings={{
        id: 1,
        githubUrl: 'https://github.com/example/repo',
        githubLabel: 'View source',
      }}
    />,
  );
  expect(screen.getByRole('link', { name: 'View source' })).toBeTruthy();
});

it('falls back to the plan-sanctioned "GitHub" label when unset', () => {
  render(
    <SiteHeader
      siteSettings={{ id: 1, githubUrl: 'https://github.com/example/repo' }}
    />,
  );
  expect(screen.getByRole('link', { name: 'GitHub' })).toBeTruthy();
});

it('closes the mobile menu when a nav link is clicked', () => {
  render(
    <SiteHeader
      siteSettings={{
        id: 1,
        navLinks: [{ id: 'a', label: 'Docs', href: '/docs' }],
      }}
    />,
  );
  fireEvent.click(screen.getByRole('button', { name: 'Toggle navigation' }));
  const mobileLink = screen.getAllByRole('link', { name: 'Docs' })[1];
  fireEvent.click(mobileLink);
  expect(
    screen
      .getByRole('button', { name: 'Toggle navigation' })
      .getAttribute('aria-expanded'),
  ).toBe('false');
});

it('closes the mobile menu when the mobile GitHub button is clicked', () => {
  render(
    <SiteHeader
      siteSettings={{
        id: 1,
        githubUrl: 'https://github.com/example/repo',
      }}
    />,
  );
  fireEvent.click(screen.getByRole('button', { name: 'Toggle navigation' }));
  const githubLinks = screen.getAllByRole('link', { name: 'GitHub' });
  fireEvent.click(githubLinks[githubLinks.length - 1]);
  expect(
    screen
      .getByRole('button', { name: 'Toggle navigation' })
      .getAttribute('aria-expanded'),
  ).toBe('false');
});
