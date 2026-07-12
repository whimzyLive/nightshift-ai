import { render, screen } from '@testing-library/react';

import HomePage from './page';

import type { HomeFaqItem } from '../../lib/faq';

// Hero embeds the Terminal primitive (checks prefers-reduced-motion) and
// ProofBar embeds CountUp (checks IntersectionObserver support) — both are
// client components exercising browser-only APIs jsdom doesn't implement by
// default. Mirrors the mocking pattern used in cursor-glow.spec.tsx.
function mockMatchMedia() {
  window.matchMedia = jest.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
  })) as unknown as typeof window.matchMedia;
}

// The Payload fetch happens once, at this page's own top-level async
// boundary — mock the small data-access function directly rather than the
// whole Payload Local API chain (matches the boundary faq.ts exists for).
const mockGetHomeFaqs = jest.fn();
jest.mock('../../lib/faq', () => ({ getHomeFaqs: () => mockGetHomeFaqs() }));

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
];

describe('HomePage', () => {
  beforeEach(() => {
    mockMatchMedia();
    mockGetHomeFaqs.mockReset().mockResolvedValue(FAQS);
  });

  it('renders the Hero heading', async () => {
    render(await HomePage());
    expect(
      screen.getByRole('heading', { level: 1, name: /ships while you sleep/i }),
    ).toBeTruthy();
  });

  it('renders the four above-the-fold sections in order', async () => {
    const { container } = render(await HomePage());
    // Hero and FinalCta each render their own GitHub star link.
    expect(
      screen.getAllByRole('link', { name: /star nightshift on github/i }),
    ).toHaveLength(2);
    // Numbers + labels are split across CountUp's own <span> and the
    // surrounding static text, so assert on the flattened text content
    // rather than a single-node text match.
    expect(container.textContent).toContain('specialized agents');
    expect(container.textContent).toContain('the other 80%');
  });

  it('composes how-it-works, day-night-workflow, team-preview, why-different, control-section, faq-preview, and final-cta after ProblemSection, in order', async () => {
    const { container } = render(await HomePage());
    const html = container.innerHTML;
    const problemIdx = html.indexOf('the other 80%');
    const howIdx = html.indexOf('One command runs the whole lifecycle');
    const workflowIdx = html.indexOf('Review by day. Ship by night.');
    const teamIdx = html.indexOf('A team, not a megaprompt');
    const whyIdx = html.indexOf('Why builders choose it');
    const controlIdx = html.indexOf('You decide how it gets built');
    const faqIdx = html.indexOf('Questions builders ask first');
    const ctaIdx = html.indexOf(
      'Put a ticket in tonight. Read a reviewed PR in the morning.',
    );

    expect(problemIdx).toBeGreaterThan(-1);
    expect(howIdx).toBeGreaterThan(problemIdx);
    expect(workflowIdx).toBeGreaterThan(howIdx);
    expect(teamIdx).toBeGreaterThan(workflowIdx);
    expect(whyIdx).toBeGreaterThan(teamIdx);
    expect(controlIdx).toBeGreaterThan(whyIdx);
    expect(faqIdx).toBeGreaterThan(controlIdx);
    expect(ctaIdx).toBeGreaterThan(faqIdx);
  });

  it('resolves the hero "while you sleep" #workflow deep-link to the day/night section (AC2)', async () => {
    const { container } = render(await HomePage());
    const heroLink = screen.getByRole('link', { name: /while you sleep/i });
    expect(heroLink.getAttribute('href')).toBe('#workflow');
    expect(container.querySelectorAll('#workflow')).toHaveLength(1);
  });

  it('fetches the home FAQs once and passes them to FaqPreview (AC1)', async () => {
    render(await HomePage());
    expect(mockGetHomeFaqs).toHaveBeenCalledTimes(1);
    expect(screen.getByText('Isn’t this a wrapper?')).toBeTruthy();
  });
});
