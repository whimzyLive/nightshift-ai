import { render, screen } from '@testing-library/react';

import { FaqPreview } from './faq-preview';

import type { HomeFaqItem } from '../../lib/faq';

// `@payloadcms/richtext-lexical/react` ships plain ESM (`export {...}`) with
// no CJS build — Jest's default transformIgnorePatterns skips node_modules,
// so importing it un-mocked throws "Unexpected token 'export'". The real
// converter is third-party/well-tested; this fake extracts the same plain
// text our `richText()` test helper builds, which is all these tests assert.
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

function richText(text: string): HomeFaqItem['answer'] {
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
  } as unknown as HomeFaqItem['answer'];
}

const FAQS: HomeFaqItem[] = [
  { id: 1, question: 'Isn’t this a wrapper?', answer: richText('No.') },
  { id: 2, question: 'What does it cost?', answer: richText('Nothing.') },
];

describe('FaqPreview', () => {
  it('renders the section header copy', () => {
    render(<FaqPreview faqs={FAQS} />);
    expect(screen.getByText('Questions builders ask first')).toBeTruthy();
  });

  it('renders each FAQ question and its richText answer', () => {
    render(<FaqPreview faqs={FAQS} />);
    expect(screen.getByText('Isn’t this a wrapper?')).toBeTruthy();
    expect(screen.getByText('What does it cost?')).toBeTruthy();
    expect(screen.getByText('No.')).toBeTruthy();
  });

  it('links "Browse the full FAQ" to the /faq route', () => {
    render(<FaqPreview faqs={FAQS} />);
    const link = screen.getByRole('link', { name: /browse the full faq/i });
    expect(link.getAttribute('href')).toBe('/faq');
  });

  it('renders nothing when there are no home FAQs', () => {
    const { container } = render(<FaqPreview faqs={[]} />);
    expect(container.firstChild).toBeNull();
  });
});
