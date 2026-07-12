import { RichText } from '@payloadcms/richtext-lexical/react';

import { Eyebrow } from '@nightshift-ai/ui';

import type { WhySdlcFaqItem } from '../../lib/why-sdlc';

/**
 * `/why-sdlc` page FAQ — the 2-question CMS card. Server component: `faqs`
 * arrives already resolved from the page's top-level async boundary. Mirrors
 * `FaqPreview`'s RichText usage; no accordion interaction here (only 2
 * questions, both always visible per the design handoff).
 */
export function PageFaq({ faqs }: { faqs: WhySdlcFaqItem[] }) {
  if (faqs.length === 0) return null;

  return (
    <section
      className="border-t"
      style={{
        padding: '64px 28px',
        background: 'var(--bg-void)',
        borderColor: 'var(--border-default)',
      }}
    >
      <div className="mx-auto" style={{ maxWidth: 820 }}>
        <Eyebrow>questions</Eyebrow>
        <div
          className="mt-5"
          style={{
            background: 'var(--surface-card)',
            border: '1px solid var(--border-default)',
            padding: '6px 30px',
          }}
        >
          {faqs.map((faq, i) => (
            <div
              key={faq.id}
              className="[&_p]:m-0"
              style={{
                padding: '24px 0',
                borderBottom:
                  i < faqs.length - 1 ? '1px solid var(--border-soft)' : 'none',
              }}
            >
              <h3
                style={{
                  fontSize: 18,
                  color: 'var(--moon-100)',
                  margin: '0 0 8px',
                }}
              >
                {faq.question}
              </h3>
              <div
                style={{
                  fontSize: 16,
                  lineHeight: 1.65,
                  color: 'var(--text-body)',
                }}
              >
                <RichText data={faq.answer} disableContainer />
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
