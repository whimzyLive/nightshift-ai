import { Eyebrow, Reveal, RevealGroup } from '@nightshift-ai/ui';

// Verbatim from the design handoff (nightshift Landing.dc.html L211-232).
const CARDS: { title: string; body: string }[] = [
  {
    title: 'Vague ticket, no spec',
    body: '"Add auth" becomes whatever you remember at 4pm.',
  },
  {
    title: 'No enforced lifecycle',
    body: 'Runbooks exist. Nobody follows them without enforcement.',
  },
  {
    title: 'Self-review is a rubber stamp',
    body: "Reviewing your own AI output isn't review.",
  },
];

/**
 * Problem framing: ghost 80% motif, eyebrow, H2 with strikethrough/accent
 * spans, two body paragraphs, three glassmorphic scroll-reveal cards. Full-
 * bleed wrapper (Open-Question default 1) so the oversized ghost glyph can
 * clip at viewport width rather than the shared `<main>` container.
 */
export function ProblemSection() {
  return (
    <section
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen overflow-hidden ns-cv"
      style={{ padding: '80px 28px' }}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute left-1/2 -translate-x-1/2 leading-none font-sans font-extrabold select-none"
        style={{
          top: -36,
          fontSize: 'clamp(180px, 26vw, 340px)',
          letterSpacing: '-0.04em',
          color: 'rgba(245,243,239,0.035)',
        }}
      >
        80%
      </div>
      <RevealGroup
        className="relative z-[1] mx-auto text-center"
        style={{ maxWidth: 900 }}
      >
        <Reveal>
          <Eyebrow>01 · the other 80%</Eyebrow>
        </Reveal>
        <Reveal
          as="h2"
          style={{
            fontSize: 'clamp(32px, 4vw, 46px)',
            lineHeight: 1.12,
            letterSpacing: '-0.02em',
            color: 'var(--moon-100)',
            margin: '18px 0 18px',
          }}
        >
          You don&apos;t lose time{' '}
          <span
            style={{
              color: 'var(--text-dim)',
              textDecoration: 'line-through',
              textDecorationColor: 'var(--moon-500)',
            }}
          >
            writing code
          </span>
          . You lose it{' '}
          <span style={{ color: 'var(--accent)' }}>around the code</span>.
        </Reveal>
        <Reveal
          as="p"
          style={{
            fontSize: 19,
            lineHeight: 1.65,
            color: 'var(--text-muted)',
            maxWidth: 700,
            margin: '0 auto 12px',
          }}
        >
          The AI already writes the code. What still eats the sprint is the
          connective tissue: turning a vague ticket into a real spec, a spec
          into a plan, keeping the plan honest while you implement, then
          reviewing the result without rubber-stamping your own work.
        </Reveal>
        <Reveal
          as="p"
          style={{
            fontSize: 19,
            lineHeight: 1.65,
            color: 'var(--text-muted)',
            maxWidth: 700,
            margin: '0 auto',
          }}
        >
          Coding assistants handle the middle 20%. The other 80% — the{' '}
          <strong style={{ color: 'var(--moon-100)' }}>process</strong> — stays
          manual, or gets skipped on vibes and shipped unreviewed.
        </Reveal>
      </RevealGroup>
      <RevealGroup
        as="div"
        className="relative z-[1] mx-auto mt-[44px] grid grid-cols-1 gap-[16px] sm:grid-cols-3"
        style={{ maxWidth: 960 }}
        amount={0.2}
      >
        {CARDS.map((card) => (
          <Reveal
            key={card.title}
            scale={0.97}
            blur={8}
            duration={0.6}
            style={{
              // Glassmorphic surface — translucent over the starfield with a
              // backdrop blur + top highlight; the Reveal frosts it in.
              background:
                'linear-gradient(180deg, rgba(255,255,255,0.05), rgba(13,13,24,0.45))',
              backdropFilter: 'var(--glass-blur)',
              WebkitBackdropFilter: 'var(--glass-blur)',
              border: '1px solid var(--glass-border)',
              padding: 24,
              boxShadow: 'var(--elev-2), inset 0 1px 0 rgba(255,255,255,0.06)',
            }}
          >
            <h3
              style={{
                fontSize: 18,
                color: 'var(--moon-100)',
                margin: '0 0 8px',
              }}
            >
              {card.title}
            </h3>
            <p
              style={{
                fontSize: 16,
                lineHeight: 1.55,
                color: 'var(--text-muted)',
                margin: 0,
              }}
            >
              {card.body}
            </p>
          </Reveal>
        ))}
      </RevealGroup>
    </section>
  );
}
