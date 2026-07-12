import { RichText } from '@payloadcms/richtext-lexical/react';

import { Eyebrow } from '@nightshift-ai/ui';

import { FaqAccordion } from './faq-accordion';

import type { HomeFaqItem } from '../../lib/faq';

/**
 * Home section 07 — top-5 FAQ preview. Pure presentational server component:
 * the Payload fetch happens once, at the page's top-level async boundary
 * (see `(frontend)/page.tsx`), and `faqs` arrives here already resolved —
 * keeps this component (and the FaqAccordion client island it wraps) fully
 * synchronous and RTL-testable without re-mocking Payload per test (see the
 * NA-16 memory on why a second nested async Server Component breaks RTL).
 * `RichText` (from `@payloadcms/richtext-lexical/react`) carries no
 * `'use client'` directive, so converting each answer's Lexical JSON to JSX
 * stays server-side — only the toggle state ships to the client.
 */
export function FaqPreview({ faqs }: { faqs: HomeFaqItem[] }) {
  if (faqs.length === 0) return null;

  const items = faqs.map((faq) => ({
    id: faq.id,
    question: faq.question,
    answer: <RichText data={faq.answer} disableContainer />,
  }));

  return (
    <section
      className="border-t"
      style={{ padding: '80px 0', borderColor: 'var(--border-default)' }}
    >
      <div className="mx-auto" style={{ maxWidth: 800 }}>
        <div className="mb-9 text-center">
          <Eyebrow>07 · questions</Eyebrow>
          <h2
            style={{
              fontSize: 'clamp(32px, 4vw, 46px)',
              letterSpacing: '-0.02em',
              color: 'var(--moon-100)',
              margin: '14px 0 0',
            }}
          >
            Questions builders ask first
          </h2>
        </div>

        <FaqAccordion items={items} />

        <p className="mt-6 text-center">
          <a
            href="/faq"
            className="font-mono"
            style={{ fontSize: 15, color: 'var(--link)' }}
          >
            Browse the full FAQ — workflow, setup, trust, licensing →
          </a>
        </p>
      </div>
    </section>
  );
}
