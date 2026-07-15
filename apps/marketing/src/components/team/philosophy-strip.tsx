import { Reveal, RevealGroup } from '@nightshift-ai/ui';

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
        <RevealGroup
          as="div"
          className="grid gap-4"
          amount={0.2}
          style={{
            gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
          }}
        >
          {PHILOSOPHY.map((card) => (
            <Reveal
              key={card.title}
              data-lift
              scale={0.97}
              blur={8}
              duration={0.6}
              style={{
                background:
                  'linear-gradient(180deg, rgba(255,255,255,0.05), rgba(13,13,24,0.45))',
                backdropFilter: 'var(--glass-blur)',
                WebkitBackdropFilter: 'var(--glass-blur)',
                border: '1px solid var(--glass-border)',
                boxShadow:
                  'var(--elev-2), inset 0 1px 0 rgba(255,255,255,0.06)',
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
            </Reveal>
          ))}
        </RevealGroup>
      </div>
    </section>
  );
}
