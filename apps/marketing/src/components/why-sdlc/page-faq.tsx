import { RichText } from '@payloadcms/richtext-lexical/react';

import { Eyebrow, Reveal, RevealGroup } from '@nightshift-ai/ui';

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
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen border-t"
      style={{
        padding: '64px 28px',
        background: 'var(--bg-void)',
        borderColor: 'var(--border-default)',
      }}
    >
      <div className="mx-auto" style={{ maxWidth: 820 }}>
        <RevealGroup>
          <Reveal>
            <Eyebrow>questions</Eyebrow>
          </Reveal>
        </RevealGroup>
        <RevealGroup>
          <Reveal
            className="mt-5"
            scale={0.97}
            blur={8}
            duration={0.6}
            style={{
              // Glassmorphic surface — matches the approved home cards; frosts
              // the single FAQ panel into place over the void background.
              background:
                'linear-gradient(180deg, rgba(255,255,255,0.05), rgba(13,13,24,0.45))',
              backdropFilter: 'var(--glass-blur)',
              WebkitBackdropFilter: 'var(--glass-blur)',
              border: '1px solid var(--glass-border)',
              boxShadow: 'var(--elev-2), inset 0 1px 0 rgba(255,255,255,0.06)',
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
                    i < faqs.length - 1
                      ? '1px solid var(--border-soft)'
                      : 'none',
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
          </Reveal>
        </RevealGroup>
      </div>
    </section>
  );
}
