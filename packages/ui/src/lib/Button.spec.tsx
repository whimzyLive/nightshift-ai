import { render, screen, fireEvent } from '@testing-library/react';
import { Button } from './Button';

it('renders an anchor when href is provided', () => {
  render(<Button href="/why-sdlc">Learn</Button>);
  // @testing-library/jest-dom is not installed in this workspace — use the
  // base Jest matcher against the raw attribute instead of toHaveAttribute.
  expect(screen.getByRole('link', { name: 'Learn' }).getAttribute('href')).toBe(
    '/why-sdlc',
  );
});

it('forwards rest props (aria-*, id, onClick, data-*) onto the anchor when href is set', () => {
  const onClick = jest.fn();
  render(
    <Button
      href="/why-sdlc"
      id="learn-link"
      aria-label="Learn about the SDLC"
      data-testid="learn-cta"
      onClick={onClick}
    >
      Learn
    </Button>,
  );
  const link = screen.getByTestId('learn-cta');
  expect(link.getAttribute('id')).toBe('learn-link');
  expect(link.getAttribute('aria-label')).toBe('Learn about the SDLC');
  fireEvent.click(link);
  expect(onClick).toHaveBeenCalledTimes(1);
});
