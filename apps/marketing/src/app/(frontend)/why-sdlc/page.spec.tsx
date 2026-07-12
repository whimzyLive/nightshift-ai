import { render, screen } from '@testing-library/react';

import WhySdlcPage from './page';

import type { WhySdlcContent, WhySdlcFaqItem } from '../../../lib/why-sdlc';

const mockGetWhySdlcContent = jest.fn();
const mockGetWhySdlcFaqs = jest.fn();
jest.mock('../../../lib/why-sdlc', () => ({
  getWhySdlcContent: () => mockGetWhySdlcContent(),
  getWhySdlcFaqs: () => mockGetWhySdlcFaqs(),
}));

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

const CONTENT: WhySdlcContent = {
  intro: {
    eyebrow: '// why an sdlc',
    heading: 'You decide how it gets built',
    lead: richText('lead copy'),
    scrollHint: 'five sections · five gates',
  },
  arguments: [
    {
      eyebrow: '// 01 · the trend',
      heading: 'Abstraction that takes the wheel',
      body: richText('body 1'),
    },
    {
      eyebrow: '// 02 · the answer',
      heading: 'The lifecycle you already trust',
      body: richText('body 2'),
    },
    {
      eyebrow: '// 03 · hard gates',
      heading: 'Hard gates return control',
      body: richText('body 3'),
    },
    {
      eyebrow: '// 04 · no one-shot',
      heading: 'No building it all in one shot',
      body: richText('body 4'),
    },
    {
      eyebrow: '// 05 · builds like you',
      heading: 'It builds the way you would',
      body: richText('body 5'),
    },
  ],
} as unknown as WhySdlcContent;

const FAQS: WhySdlcFaqItem[] = [
  {
    id: 1,
    question: 'Isn’t this just another guardrail tool?',
    answer: richText('No.') as unknown as WhySdlcFaqItem['answer'],
  },
];

describe('WhySdlcPage', () => {
  beforeEach(() => {
    mockGetWhySdlcContent.mockReset();
    mockGetWhySdlcFaqs.mockReset();
  });

  it('fetches content and faqs once each', async () => {
    mockGetWhySdlcContent.mockResolvedValue(CONTENT);
    mockGetWhySdlcFaqs.mockResolvedValue(FAQS);
    render(await WhySdlcPage());
    expect(mockGetWhySdlcContent).toHaveBeenCalledTimes(1);
    expect(mockGetWhySdlcFaqs).toHaveBeenCalledTimes(1);
  });

  it('renders the hero heading, argument cards, FAQ, and CTA when content is present', async () => {
    mockGetWhySdlcContent.mockResolvedValue(CONTENT);
    mockGetWhySdlcFaqs.mockResolvedValue(FAQS);
    const { container } = render(await WhySdlcPage());
    expect(
      screen.getByRole('heading', {
        level: 1,
        name: 'You decide how it gets built',
      }),
    ).toBeTruthy();
    expect(container.querySelectorAll('[data-why-sec]')).toHaveLength(5);
    expect(
      screen.getByText('Isn’t this just another guardrail tool?'),
    ).toBeTruthy();
    expect(
      screen.getByRole('heading', {
        name: 'Put the lifecycle back in your hands',
      }),
    ).toBeTruthy();
  });

  it('renders nothing for hero/argument sections but still renders the CTA when content is null', async () => {
    mockGetWhySdlcContent.mockResolvedValue(null);
    mockGetWhySdlcFaqs.mockResolvedValue([]);
    const { container } = render(await WhySdlcPage());
    expect(screen.queryByRole('heading', { level: 1 })).toBeNull();
    expect(container.querySelectorAll('[data-why-sec]')).toHaveLength(0);
    expect(
      screen.getByRole('heading', {
        name: 'Put the lifecycle back in your hands',
      }),
    ).toBeTruthy();
  });
});
