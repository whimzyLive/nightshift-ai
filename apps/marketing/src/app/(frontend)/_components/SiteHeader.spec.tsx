import { render, screen } from '@testing-library/react';
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
