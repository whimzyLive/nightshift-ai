import { Eyebrow } from '@nightshift-ai/ui';

/**
 * `/faq` header — breadcrumb, eyebrow, H1, subhead, terra glow. Static
 * server component (no CMS read of its own — the copy is fixed page chrome,
 * same as `why-sdlc/hero.tsx`'s breadcrumb/glow treatment), just with the
 * glow anchored top-right per the design handoff (faq.dc.html).
 */
export function FaqHero() {
  return (
    <section
      className="relative border-b"
      style={{
        padding: '72px 28px 48px',
        borderColor: 'var(--border-default)',
      }}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute rounded-full blur-[10px]"
        style={{
          top: -120,
          right: -60,
          width: 420,
          height: 420,
          background:
            'radial-gradient(circle, var(--terra-glow), transparent 62%)',
        }}
      />
      <div className="relative z-[1] mx-auto" style={{ maxWidth: 860 }}>
        <nav
          className="font-mono"
          style={{ fontSize: 13, color: 'var(--text-dim)', marginBottom: 24 }}
        >
          <a href="/" style={{ color: 'var(--text-muted)' }}>
            Home
          </a>{' '}
          <span style={{ color: 'var(--moon-500)' }}>/</span>{' '}
          <span style={{ color: 'var(--moon-300)' }}>FAQ</span>
        </nav>
        <Eyebrow>questions</Eyebrow>
        <h1
          className="font-sans font-extrabold"
          style={{
            fontSize: 'clamp(34px, 4.6vw, 54px)',
            lineHeight: 1.06,
            letterSpacing: '-0.025em',
            color: 'var(--moon-100)',
            margin: '16px 0 16px',
          }}
        >
          Everything builders ask
        </h1>
        <p
          style={{
            fontSize: 18,
            lineHeight: 1.65,
            color: 'var(--text-muted)',
            maxWidth: 620,
            margin: 0,
          }}
        >
          The full set, grouped by topic. Click any question — one answer open
          at a time.
        </p>
      </div>
    </section>
  );
}
