import { render, screen } from '@testing-library/react';

import { CtaButton } from './button';

describe('CtaButton', () => {
  it('renders a <button> when no href is given', () => {
    render(<CtaButton>Install</CtaButton>);
    const el = screen.getByRole('button', { name: 'Install' });
    expect(el.tagName).toBe('BUTTON');
  });

  it('renders an internal href as a routable link', () => {
    render(<CtaButton href="/why-sdlc">Why SDLC</CtaButton>);
    const el = screen.getByRole('link', { name: 'Why SDLC' });
    expect(el.getAttribute('href')).toBe('/why-sdlc');
  });

  it('renders an external href as a plain anchor', () => {
    render(
      <CtaButton href="https://github.com/whimzyLive/nightshift-ai">
        GitHub
      </CtaButton>,
    );
    const el = screen.getByRole('link', { name: 'GitHub' });
    expect(el.tagName).toBe('A');
    expect(el.getAttribute('href')).toBe(
      'https://github.com/whimzyLive/nightshift-ai',
    );
  });

  it('renders an in-page anchor href (not external) as a routable link', () => {
    render(<CtaButton href="/#install">Install the plugin</CtaButton>);
    const el = screen.getByRole('link', { name: 'Install the plugin' });
    expect(el.getAttribute('href')).toBe('/#install');
  });
});
