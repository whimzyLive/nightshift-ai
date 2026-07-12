import { RichText } from '@payloadcms/richtext-lexical/react';

import { Eyebrow } from '@nightshift-ai/ui';

import type { WhySdlcIntro } from '../../lib/why-sdlc';

/**
 * `/why-sdlc` header — breadcrumb, eyebrow, H1, lead paragraph (richText),
 * and the mono scroll hint. Server component: `intro` arrives already
 * resolved from the page's single top-level async boundary (see NA-16
 * memory). Renders nothing when the CMS global couldn't be read.
 */
export function Hero({ intro }: { intro: WhySdlcIntro | null }) {
  if (!intro) return null;

  return (
    <section
      className="relative border-b"
      style={{
        padding: '64px 28px 52px',
        borderColor: 'var(--border-default)',
      }}
    >
      {/* Bright centre kept off-screen top-left and heavily blurred so the
          glow fades to nothing well inside the section — no hard clip edge
          against the page background. */}
      <div
        aria-hidden="true"
        className="pointer-events-none absolute rounded-full blur-[60px]"
        style={{
          top: -260,
          left: -200,
          width: 620,
          height: 620,
          background:
            'radial-gradient(circle, var(--terra-glow), transparent 66%)',
        }}
      />
      <div className="relative z-[1] mx-auto" style={{ maxWidth: 820 }}>
        <nav
          className="font-mono"
          style={{ fontSize: 13, color: 'var(--text-dim)', marginBottom: 24 }}
        >
          <a href="/" style={{ color: 'var(--text-muted)' }}>
            Home
          </a>{' '}
          <span style={{ color: 'var(--moon-500)' }}>/</span>{' '}
          <span style={{ color: 'var(--moon-300)' }}>Why SDLC</span>
        </nav>
        <Eyebrow>{intro.eyebrow.replace(/^\/\/\s*/, '')}</Eyebrow>
        <h1
          className="font-sans font-extrabold"
          style={{
            fontSize: 'clamp(34px, 4.6vw, 54px)',
            lineHeight: 1.06,
            letterSpacing: '-0.025em',
            color: 'var(--moon-100)',
            margin: '16px 0 18px',
          }}
        >
          {intro.heading}
        </h1>
        <div
          className="[&_p]:m-0 [&_p]:max-w-[640px]"
          style={{ fontSize: 19, lineHeight: 1.65, color: 'var(--text-muted)' }}
        >
          <RichText data={intro.lead} disableContainer />
        </div>
        <p
          className="font-mono"
          style={{ fontSize: 13, color: 'var(--text-dim)', margin: '20px 0 0' }}
        >
          {intro.scrollHint}
        </p>
      </div>
    </section>
  );
}
