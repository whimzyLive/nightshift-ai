import { PHILOSOPHY } from './roster-data';

/**
 * Full-bleed philosophy band — team.dc.html L107-129. Four cards in an
 * auto-fit grid; card titles are the `// ...` mono eyebrows.
 */
export function PhilosophyStrip() {
  return (
    <section
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen border-b"
      style={{
        padding: '56px 28px',
        background: 'var(--bg-void)',
        borderColor: 'var(--border-default)',
      }}
    >
      <div className="mx-auto" style={{ maxWidth: 1120 }}>
        <div
          className="grid gap-4"
          style={{
            gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
          }}
        >
          {PHILOSOPHY.map((card) => (
            <div
              key={card.title}
              style={{
                background: 'var(--surface-card)',
                border: '1px solid var(--border-default)',
                padding: '22px 24px',
              }}
            >
              <div
                className="font-mono uppercase"
                style={{
                  fontSize: 12,
                  letterSpacing: '.14em',
                  color: 'var(--accent)',
                  marginBottom: 10,
                }}
              >
                {card.title}
              </div>
              <p
                style={{
                  fontSize: 15,
                  lineHeight: 1.6,
                  color: 'var(--text-muted)',
                  margin: 0,
                }}
              >
                {card.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
