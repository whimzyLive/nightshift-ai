import { render, screen } from '@testing-library/react';

import { Eyebrow } from './eyebrow';

describe('Eyebrow', () => {
  it('prefixes the label with the mono `//` marker', () => {
    render(<Eyebrow>how it works</Eyebrow>);
    expect(screen.getByText('how it works')).toBeTruthy();
    expect(screen.getByText('//')).toBeTruthy();
  });
});
