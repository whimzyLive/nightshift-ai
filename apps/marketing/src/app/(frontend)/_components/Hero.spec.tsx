import { render, screen } from '@testing-library/react';
import { Hero } from './Hero';

it('renders an empty state when content is undefined', () => {
  expect(() =>
    render(<Hero content={undefined} siteSettings={undefined} />),
  ).not.toThrow();
});

it('renders the CMS-sourced installCtaLabel as the install snippet caption', () => {
  render(
    <Hero
      content={{ installCtaLabel: 'Install in 60 seconds' }}
      siteSettings={{ id: 1, installCommand: '/plugin install nightshift' }}
    />,
  );
  expect(screen.getByText('Install in 60 seconds')).toBeTruthy();
});
