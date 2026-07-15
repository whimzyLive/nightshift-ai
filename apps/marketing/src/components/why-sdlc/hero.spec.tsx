import { render, screen } from '@testing-library/react';

import { Hero } from './hero';

import type { WhySdlcIntro } from '../../lib/why-sdlc';

// `@payloadcms/richtext-lexical/react` ships plain ESM with no CJS build —
// see the identical mock + comment in faq-preview.spec.tsx.
jest.mock('@payloadcms/richtext-lexical/react', () => ({
  RichText: ({
    data,
  }: {
    data: {
      root: { children: Array<{ children?: Array<{ text?: string }> }> };
    };
  }) => {
    const text = data.root.children
      .flatMap((node) => node.children ?? [])
      .map((leaf) => leaf.text ?? '')
      .join('');
    return <p>{text}</p>;
  },
}));

function richText(text: string): WhySdlcIntro['lead'] {
  return {
    root: {
      type: 'root',
      direction: 'ltr',
      format: '',
      indent: 0,
      version: 1,
      children: [
        {
          type: 'paragraph',
          version: 1,
          children: [{ type: 'text', version: 1, text, format: 0 }],
        },
      ],
    },
  } as unknown as WhySdlcIntro['lead'];
}

const INTRO: WhySdlcIntro = {
  eyebrow: '// why an sdlc',
  heading: 'You decide how it gets built',
  lead: richText('Frameworks keep promising to do everything for you.'),
  scrollHint: 'five sections · five gates',
};

describe('Hero', () => {
  it('renders the Home / Why SDLC breadcrumb with a home link', () => {
    render(<Hero intro={INTRO} />);
    const homeLink = screen.getByRole('link', { name: 'Home' });
    expect(homeLink.getAttribute('href')).toBe('/');
    expect(screen.getByText('Why SDLC')).toBeTruthy();
  });

  it('renders the eyebrow from intro.eyebrow', () => {
    render(<Hero intro={INTRO} />);
    expect(screen.getByText('why an sdlc')).toBeTruthy();
  });

  it('renders the heading as an h1 from intro.heading', () => {
    render(<Hero intro={INTRO} />);
    expect(
      screen.getByRole('heading', {
        level: 1,
        name: 'You decide how it gets built',
      }),
    ).toBeTruthy();
  });

  it('renders the mono scrollHint line', () => {
    render(<Hero intro={INTRO} />);
    expect(screen.getByText('five sections · five gates')).toBeTruthy();
  });

  it('renders nothing when intro is nullish', () => {
    const { container } = render(<Hero intro={null} />);
    expect(container.firstChild).toBeNull();
  });
});
