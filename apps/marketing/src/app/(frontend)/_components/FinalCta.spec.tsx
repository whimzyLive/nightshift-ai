import { render, screen } from '@testing-library/react';
import { FinalCta } from './FinalCta';

it('renders an empty state when content is undefined', () => {
  expect(() =>
    render(<FinalCta content={undefined} siteSettings={undefined} />),
  ).not.toThrow();
});

it('renders the CMS-sourced starCtaLabel on the GitHub button', () => {
  render(
    <FinalCta
      content={{ heading: 'Ship tonight', body: 'Get started.' }}
      siteSettings={{ id: 1, githubUrl: 'https://github.com/example/repo' }}
      starCtaLabel="Give us a star"
    />,
  );
  expect(screen.getByRole('link', { name: 'Give us a star' })).toBeTruthy();
});

it('falls back to the plan-sanctioned "Star on GitHub" label when unset', () => {
  render(
    <FinalCta
      content={{ heading: 'Ship tonight', body: 'Get started.' }}
      siteSettings={{ id: 1, githubUrl: 'https://github.com/example/repo' }}
    />,
  );
  expect(screen.getByRole('link', { name: 'Star on GitHub' })).toBeTruthy();
});
