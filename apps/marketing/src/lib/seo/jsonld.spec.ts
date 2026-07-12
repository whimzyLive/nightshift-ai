import { faqAnswerToPlaintext } from './faq-plaintext';
import {
  buildFaqPageNode,
  howToNode,
  organizationNode,
  softwareApplicationNode,
  whySdlcBreadcrumbNode,
  whySdlcWebPageNode,
} from './jsonld';

import type { FaqSchemaInput } from './jsonld';
import type { SerializedEditorState } from '@payloadcms/richtext-lexical/lexical';

// `@payloadcms/richtext-lexical/plaintext` ships plain ESM with no CJS build
// — same convention as the `/react` mock used across the page.spec.tsx
// files (e.g. why-sdlc/page.spec.tsx). The fake reproduces the real
// converter's heuristic closely enough for these flat single-paragraph
// fixtures: concatenate every leaf text node's `text`.
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

function richText(text: string): SerializedEditorState {
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
  } as unknown as SerializedEditorState;
}

describe('buildFaqPageNode', () => {
  it('returns null for an empty faqs array', () => {
    expect(buildFaqPageNode('https://example.com#faq', [])).toBeNull();
  });

  it('builds a FAQPage node with one Question per faq, at the given @id', () => {
    const faqs: FaqSchemaInput[] = [
      { question: 'Q1', answer: richText('A1') },
      { question: 'Q2', answer: richText('A2') },
    ];

    const node = buildFaqPageNode('https://example.com#faq', faqs);

    expect(node).not.toBeNull();
    expect(node?.['@type']).toBe('FAQPage');
    expect(node?.['@id']).toBe('https://example.com#faq');
    expect(node?.mainEntity).toHaveLength(2);
    expect(node?.mainEntity[0]).toEqual({
      '@type': 'Question',
      name: 'Q1',
      acceptedAnswer: { '@type': 'Answer', text: 'A1' },
    });
    expect(node?.mainEntity[1]).toEqual({
      '@type': 'Question',
      name: 'Q2',
      acceptedAnswer: { '@type': 'Answer', text: 'A2' },
    });
  });

  it('produces answer.text identical to faqAnswerToPlaintext of the same Lexical value (AC4)', () => {
    const answer = richText('identity check');
    const faqs: FaqSchemaInput[] = [{ question: 'Q', answer }];

    const node = buildFaqPageNode('https://example.com#faq', faqs);

    expect(node?.mainEntity[0].acceptedAnswer.text).toBe(
      faqAnswerToPlaintext(answer),
    );
  });
});

describe('static JSON-LD node constants', () => {
  it('softwareApplicationNode carries absolute @id/url/downloadUrl', () => {
    expect(softwareApplicationNode['@id'].startsWith('https://')).toBe(true);
    expect(softwareApplicationNode.url.startsWith('https://')).toBe(true);
    expect(softwareApplicationNode.downloadUrl.startsWith('https://')).toBe(
      true,
    );
  });

  it('organizationNode carries an absolute @id/url', () => {
    expect(organizationNode['@id'].startsWith('https://')).toBe(true);
    expect(organizationNode.url.startsWith('https://')).toBe(true);
  });

  it('howToNode carries an absolute @id', () => {
    expect(howToNode['@id'].startsWith('https://')).toBe(true);
  });

  it('whySdlcWebPageNode and whySdlcBreadcrumbNode carry absolute @id/item URLs', () => {
    expect(whySdlcWebPageNode['@id'].startsWith('https://')).toBe(true);
    expect(whySdlcBreadcrumbNode['@id'].startsWith('https://')).toBe(true);
    for (const item of whySdlcBreadcrumbNode.itemListElement) {
      expect(item.item.startsWith('https://')).toBe(true);
    }
  });
});
