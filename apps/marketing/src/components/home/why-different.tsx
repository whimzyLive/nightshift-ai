import { Eyebrow, Reveal, RevealGroup } from '@nightshift-ai/ui';

// Verbatim from the design handoff (nightshift Landing.dc.html L376-401).
const VALUES: { title: string; body: React.ReactNode }[] = [
  {
    title: 'The lifecycle is the product',
    body: 'Spec → plan → implement → review, enforced by the commands and the handoff protocol. Tests are the merge gate. Review is done by a different agent than the one who wrote the code.',
  },
  {
    title: 'Generic agents, per-repo config',
    body: (
      <>
        No hardcoding. Every project fact lives in one{' '}
        <code style={{ color: 'var(--terra-400)' }}>project-context.md</code>.
        The same plugin runs a Node monorepo, a Python service, or a mobile app.
      </>
    ),
  },
  {
    title: 'Issue-tracker native',
    body: 'It reads the ticket, derives the branch, plan, and PR, and comments the result back to Jira and GitHub.',
  },
  {
    title: 'Free, open, yours to fork',
    body: 'Built on open Claude Code primitives, MIT-licensed. Fork it, extend it, swap a role. No lock-in, no paid tier gate.',
  },
];

/**
 * Why-different: eyebrow/header, then a 2x2 grid of value cards. The header
 * and cards ride the shared scroll-reveal system — each card is a glassmorphic
 * `Reveal` that frosts into place as the grid scrolls into view.
 */
export function WhyDifferent() {
  return (
    <section
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen border-t ns-cv"
      style={{ padding: '80px 28px', borderColor: 'var(--border-default)' }}
    >
      <div className="mx-auto" style={{ maxWidth: 1000 }}>
        <RevealGroup className="mb-10 text-center">
          <Reveal>
            <Eyebrow>05 · why different</Eyebrow>
          </Reveal>
          <Reveal
            as="h2"
            style={{
              fontSize: 'clamp(32px, 4vw, 46px)',
              letterSpacing: '-0.02em',
              color: 'var(--moon-100)',
              margin: '14px 0 0',
            }}
          >
            Why builders choose it
          </Reveal>
        </RevealGroup>
        <RevealGroup
          as="div"
          className="grid grid-cols-1 gap-4 sm:grid-cols-2"
          amount={0.2}
        >
          {VALUES.map((value) => (
            <Reveal
              data-lift
              key={value.title}
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
                boxShadow:
                  'var(--elev-2), inset 0 1px 0 rgba(255,255,255,0.06)',
              }}
            >
              <h3
                style={{
                  fontSize: 20,
                  color: 'var(--moon-100)',
                  margin: '0 0 10px',
                }}
              >
                {value.title}
              </h3>
              <p
                style={{
                  fontSize: 16,
                  lineHeight: 1.6,
                  color: 'var(--text-muted)',
                  margin: 0,
                }}
              >
                {value.body}
              </p>
            </Reveal>
          ))}
        </RevealGroup>
      </div>
    </section>
  );
}
