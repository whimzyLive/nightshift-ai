import { render } from '@testing-library/react';
import { Hero } from './Hero';

it('renders an empty state when content is undefined', () => {
  expect(() =>
    render(<Hero content={undefined} siteSettings={undefined} />),
  ).not.toThrow();
});
