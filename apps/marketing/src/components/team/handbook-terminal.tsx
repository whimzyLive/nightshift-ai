import { HANDBOOK_STEPS } from './roster-data';

/**
 * Full-bleed "enforced handbook" band — team.dc.html L182-196. A
 * `var(--surface-terminal)` numbered list of the six onboarding steps.
 */
export function HandbookTerminal() {
  return (
    <section
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen border-t"
      style={{
        padding: '56px 28px',
        background: 'var(--bg-void)',
        borderColor: 'var(--border-default)',
      }}
    >
      <div className="mx-auto" style={{ maxWidth: 1120 }}>
        <span
          className="font-mono uppercase"
          style={{
            fontSize: 13,
            letterSpacing: '.16em',
            color: 'var(--accent)',
          }}
        >
          // company handbook, enforced
        </span>
        <h2
          style={{
            fontSize: 'clamp(24px, 2.8vw, 32px)',
            letterSpacing: '-0.02em',
            color: 'var(--moon-100)',
            margin: '12px 0 22px',
          }}
        >
          Every employee follows the same first day, every day
        </h2>
        <ol
          className="list-none font-mono"
          style={{
            background: 'var(--surface-terminal)',
            border: '1px solid var(--border-default)',
            padding: '24px 28px',
            fontSize: 14,
            lineHeight: 2.1,
            color: 'var(--moon-200)',
            overflowX: 'auto',
          }}
        >
          {HANDBOOK_STEPS.map((step, index) => (
            <li key={step}>
              {index + 1}. {step}
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
