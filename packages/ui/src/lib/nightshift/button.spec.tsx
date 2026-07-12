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

  it('defaults to the primary variant at md size', () => {
    render(<CtaButton>Install</CtaButton>);
    const el = screen.getByRole('button', { name: 'Install' });
    expect(el.className).toContain('px-6');
    expect(el.className).toContain('bg-[var(--btn-neon-bg)]');
  });

  it('renders the secondary sm variant with token-backed classes, no size/variant DOM leakage', () => {
    render(
      <CtaButton variant="secondary" size="sm">
        run it again ↺
      </CtaButton>,
    );
    const el = screen.getByRole('button', { name: 'run it again ↺' });
    expect(el.className).toContain('h-[34px]');
    expect(el.className).toContain('border-[var(--border-default)]');
    expect(el.className).toContain('hover:shadow-[var(--glow-cool)]');
    expect(el.getAttribute('size')).toBeNull();
    expect(el.getAttribute('variant')).toBeNull();
  });

  it('renders the secondary lg variant (design handoff Final CTA star button)', () => {
    render(
      <CtaButton
        variant="secondary"
        size="lg"
        href="https://github.com/whimzyLive/nightshift-ai"
      >
        ★ Star nightshift on GitHub
      </CtaButton>,
    );
    const el = screen.getByRole('link', { name: /star nightshift on github/i });
    expect(el.className).toContain('h-12');
    expect(el.className).toContain('bg-transparent');
  });
});
