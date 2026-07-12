import { Card, Eyebrow } from '@nightshift-ai/ui';

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
 * Why-different: eyebrow/header, then a 2x2 grid of value cards. Reuses
 * `Card` for the accent hover-ring (AC4) — no custom hover logic needed.
 */
export function WhyDifferent() {
  return (
    <section
      className="border-t"
      style={{ padding: '80px 0', borderColor: 'var(--border-default)' }}
    >
      <div className="mx-auto" style={{ maxWidth: 1000 }}>
        <div className="mb-10 text-center">
          <Eyebrow>05 · why different</Eyebrow>
          <h2
            style={{
              fontSize: 'clamp(32px, 4vw, 46px)',
              letterSpacing: '-0.02em',
              color: 'var(--moon-100)',
              margin: '14px 0 0',
            }}
          >
            Why builders choose it
          </h2>
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {VALUES.map((value) => (
            <Card key={value.title}>
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
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}
