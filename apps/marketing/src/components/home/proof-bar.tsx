import { CountUp, Reveal, RevealGroup } from '@nightshift-ai/ui';

/**
 * Full-bleed `--surface-card` band with top/bottom hairlines. Breaks out of
 * the shared `<main>` container to viewport width while keeping inner
 * content centered (Open-Question default 1) — the animated numerals reuse
 * one `CountUp` instance each, counting once on first viewport entry.
 */
export function ProofBar() {
  return (
    <section
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen"
      style={{
        background: 'var(--surface-card)',
        borderTop: '1px solid var(--border-default)',
        borderBottom: '1px solid var(--border-default)',
      }}
    >
      <RevealGroup
        as="div"
        className="mx-auto flex flex-wrap items-center justify-center gap-x-[28px] gap-y-[14px]"
        style={{ maxWidth: 1000, padding: '22px 28px' }}
      >
        <Reveal
          as="span"
          className="font-mono whitespace-nowrap"
          style={{ fontSize: 17, color: 'var(--moon-100)' }}
        >
          <CountUp value={11} className="text-[var(--accent)]" /> specialized
          agents
        </Reveal>
        <Reveal as="span" style={{ color: 'var(--moon-500)' }}>
          ·
        </Reveal>
        <Reveal
          as="span"
          className="font-mono whitespace-nowrap"
          style={{ fontSize: 17, color: 'var(--moon-100)' }}
        >
          <CountUp value={10} className="text-[var(--accent)]" /> slash commands
        </Reveal>
        <Reveal as="span" style={{ color: 'var(--moon-500)' }}>
          ·
        </Reveal>
        <Reveal
          as="span"
          className="font-mono whitespace-nowrap"
          style={{ fontSize: 17, color: 'var(--moon-100)' }}
        >
          install in{' '}
          <span style={{ color: 'var(--accent)' }}>
            <CountUp value={60} /> seconds
          </span>
        </Reveal>
        <Reveal as="span" style={{ color: 'var(--moon-500)' }}>
          ·
        </Reveal>
        <Reveal
          as="span"
          className="font-mono whitespace-nowrap"
          style={{ fontSize: 17, color: 'var(--moon-100)' }}
        >
          free · MIT
        </Reveal>
      </RevealGroup>
    </section>
  );
}
