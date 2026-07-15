import { render, screen } from '@testing-library/react';

import { PageFaq } from './page-faq';

import type { WhySdlcFaqItem } from '../../lib/why-sdlc';

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

function richText(text: string): WhySdlcFaqItem['answer'] {
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
  } as unknown as WhySdlcFaqItem['answer'];
}

const FAQS: WhySdlcFaqItem[] = [
  {
    id: 1,
    question: "Isn't this just another guardrail tool?",
    answer: richText('Guardrail tools constrain the output at the edges.'),
  },
  {
    id: 2,
    question: "Doesn't a full lifecycle slow me down?",
    answer: richText('Small stories skip the ceremony.'),
  },
];

describe('PageFaq', () => {
  it('renders both questions and answers from a 2-item faqs list', () => {
    render(<PageFaq faqs={FAQS} />);
    expect(
      screen.getByText("Isn't this just another guardrail tool?"),
    ).toBeTruthy();
    expect(
      screen.getByText('Guardrail tools constrain the output at the edges.'),
    ).toBeTruthy();
    expect(
      screen.getByText("Doesn't a full lifecycle slow me down?"),
    ).toBeTruthy();
    expect(screen.getByText('Small stories skip the ceremony.')).toBeTruthy();
  });

  it('returns null for an empty faqs list', () => {
    const { container } = render(<PageFaq faqs={[]} />);
    expect(container.firstChild).toBeNull();
  });
});
