import { render, screen } from '@testing-library/react';
import { Button } from './Button';

it('renders an anchor when href is provided', () => {
  render(<Button href="/why-sdlc">Learn</Button>);
  // @testing-library/jest-dom is not installed in this workspace — use the
  // base Jest matcher against the raw attribute instead of toHaveAttribute.
  expect(screen.getByRole('link', { name: 'Learn' }).getAttribute('href')).toBe(
    '/why-sdlc',
  );
});
