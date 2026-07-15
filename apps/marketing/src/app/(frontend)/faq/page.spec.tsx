import { render, screen } from '@testing-library/react';

import FaqPage from './page';

import type { FaqPageGroup } from '../../../lib/faq';

const mockGetFaqPageGroups = jest.fn();
jest.mock('../../../lib/faq', () => ({
  getFaqPageGroups: () => mockGetFaqPageGroups(),
}));

// `@payloadcms/richtext-lexical/react` ships plain ESM with no CJS build —
// see the identical mock + comment in faq-preview.spec.tsx / why-sdlc's
// page.spec.tsx.
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

// `@payloadcms/richtext-lexical/plaintext` (pulled in transitively via
// lib/seo/jsonld.ts's buildFaqPageNode, NA-39) ships plain ESM too — same
// convention as the `/react` mock above.
jest.mock('@payloadcms/richtext-lexical/plaintext', () => ({
  convertLexicalToPlaintext: ({
    data,
  }: {
    data: {
      root: { children: Array<{ children?: Array<{ text?: string }> }> };
    };
  }) =>
    data.root.children
      .flatMap((node) => node.children ?? [])
      .map((leaf) => leaf.text ?? '')
      .join(''),
}));

function richText(text: string) {
  return {
    root: {
      type: 'root',
      direction: 'ltr' as const,
      format: '' as const,
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
  };
}

const GROUPS: FaqPageGroup[] = [
  {
    key: 'positioning',
    eyebrow: '// positioning',
    items: [
      {
        id: 1,
        number: 1,
        question: 'Isn’t this just another wrapper?',
        answer: richText(
          'No.',
        ) as unknown as FaqPageGroup['items'][number]['answer'],
      },
    ],
  },
];

describe('FaqPage', () => {
  beforeEach(() => {
    mockGetFaqPageGroups.mockReset();
  });

  it('fetches the grouped faqs once', async () => {
    mockGetFaqPageGroups.mockResolvedValue(GROUPS);
    render(await FaqPage());
    expect(mockGetFaqPageGroups).toHaveBeenCalledTimes(1);
  });

  it('renders the hero heading, grouped questions, and the CTA when groups are present', async () => {
    mockGetFaqPageGroups.mockResolvedValue(GROUPS);
    render(await FaqPage());
    expect(
      screen.getByRole('heading', {
        level: 1,
        name: 'Everything builders ask',
      }),
    ).toBeTruthy();
    expect(screen.getByText('Isn’t this just another wrapper?')).toBeTruthy();
    expect(
      screen.getByRole('heading', {
        name: 'Question answered? Put a ticket in tonight.',
      }),
    ).toBeTruthy();
  });

  it('still renders the hero and CTA when getFaqPageGroups returns []', async () => {
    mockGetFaqPageGroups.mockResolvedValue([]);
    render(await FaqPage());
    expect(
      screen.getByRole('heading', {
        level: 1,
        name: 'Everything builders ask',
      }),
    ).toBeTruthy();
    expect(
      screen.getByRole('heading', {
        name: 'Question answered? Put a ticket in tonight.',
      }),
    ).toBeTruthy();
  });
});
