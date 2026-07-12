import { Eyebrow } from '@nightshift-ai/ui';

/**
 * `/team` header — breadcrumb, eyebrow, H1, intro paragraph, and the mono
 * stats line. Verbatim copy from team.dc.html (L88-104). Server component,
 * stays within the layout container (not full-bleed).
 */
export function TeamHero() {
  return (
    <section
      className="relative border-b"
      style={{
        padding: '72px 28px 56px',
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
      <div className="relative z-[1] mx-auto" style={{ maxWidth: 1120 }}>
        <nav
          className="font-mono"
          style={{ fontSize: 13, color: 'var(--text-dim)', marginBottom: 24 }}
        >
          <a href="/" style={{ color: 'var(--text-muted)' }}>
            Home
          </a>{' '}
          <span style={{ color: 'var(--moon-500)' }}>/</span>{' '}
          <span style={{ color: 'var(--moon-300)' }}>The team</span>
        </nav>
        <Eyebrow>the team</Eyebrow>
        <h1
          className="font-sans font-extrabold"
          style={{
            fontSize: 'clamp(36px, 4.8vw, 56px)',
            lineHeight: 1.05,
            letterSpacing: '-0.025em',
            color: 'var(--moon-100)',
            margin: '16px 0 18px',
            maxWidth: 820,
          }}
        >
          Meet the team that works while you sleep
        </h1>
        <p
          style={{
            fontSize: 19,
            lineHeight: 1.65,
            color: 'var(--text-muted)',
            maxWidth: 660,
            margin: '0 0 22px',
          }}
        >
          A real delivery org, not a megaprompt: one human who makes every
          decision, and specialized agents with tight charters, clean handoffs,
          and an auditable artifact at every stage. Every profile below links to
          that agent&apos;s actual charter in the repo.
        </p>
        <p
          className="font-mono"
          style={{ fontSize: 14, color: 'var(--moon-200)', margin: 0 }}
        >
          11 agents on staff · 1 opt-in specialist · hallucinating across roles:
          not permitted
        </p>
      </div>
    </section>
  );
}
