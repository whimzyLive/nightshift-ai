import { Eyebrow } from '@nightshift-ai/ui';

interface WorkflowCard {
  eyebrow: string;
  eyebrowColor: string;
  title: string;
  body: React.ReactNode;
  accent?: boolean;
}

// Verbatim from the design handoff (nightshift Landing.dc.html L283-317).
const CARDS: WorkflowCard[] = [
  {
    eyebrow: '☀ Day',
    eyebrowColor: 'var(--indigo-400)',
    title: 'You refine',
    body: "Every story gets pre-refined with clear acceptance criteria, and the complicated ones get a full spec. You read the refined stories and specs, decide what's ready, and approve them. You make the calls. You don't write the implementation.",
  },
  {
    eyebrow: '🌙 Night',
    eyebrowColor: 'var(--accent)',
    title: 'The plugin implements',
    accent: true,
    body: (
      <>
        <code style={{ color: 'var(--terra-400)' }}>/auto</code> picks up the
        tickets and specs you already approved, triages each one, and routes it
        to the right approach — following the practices your domain agents
        enforce for that repo (from its{' '}
        <code style={{ color: 'var(--terra-400)' }}>project-context.md</code>
        ). Nothing runs on work you haven&apos;t signed off.
      </>
    ),
  },
  {
    eyebrow: '↑ Morning',
    eyebrowColor: 'var(--indigo-400)',
    title: 'You review',
    body: "You wake up to PRs ready for review. Each one addresses acceptance criteria you already agreed to, or a spec you already approved. You're reading a result you set up, not a surprise.",
  },
];

/**
 * Review-by-day/ship-by-night workflow. `id="workflow"` is the hero's
 * `while you sleep` deep-link target (AC2) — the night card is the only
 * accent-ringed card in the 3-column grid, matching the design's visual
 * emphasis on the automated stage.
 */
export function DayNightWorkflow() {
  return (
    <section
      id="workflow"
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen border-t"
      style={{ padding: '84px 28px', borderColor: 'var(--border-default)' }}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute rounded-full blur-[10px]"
        style={{
          top: -140,
          right: -90,
          width: 420,
          height: 420,
          background:
            'radial-gradient(circle, rgba(124,147,240,.18), transparent 62%)',
        }}
      />
      <div className="relative mx-auto" style={{ zIndex: 1, maxWidth: 1000 }}>
        <div className="mb-4 text-center">
          <Eyebrow>03 · your day, split in two</Eyebrow>
          <h2
            style={{
              fontSize: 'clamp(32px, 4vw, 46px)',
              letterSpacing: '-0.02em',
              color: 'var(--moon-100)',
              margin: '14px 0 14px',
            }}
          >
            Review by day. Ship by night.
          </h2>
          <p
            className="mx-auto"
            style={{
              fontSize: 18,
              lineHeight: 1.6,
              color: 'var(--text-muted)',
              maxWidth: 620,
            }}
          >
            &quot;Ships while you sleep&quot; is a workflow, not a slogan. The
            split is simple: your day is for decisions, the night is for
            execution.
          </p>
        </div>

        <div
          className="mx-auto flex items-center gap-[14px] font-mono"
          style={{
            maxWidth: 760,
            margin: '36px auto 20px',
            fontSize: 13,
            letterSpacing: '0.1em',
          }}
        >
          <span style={{ color: 'var(--indigo-400)', whiteSpace: 'nowrap' }}>
            ☀ 09:00
          </span>
          <div
            className="h-px flex-1"
            style={{
              background:
                'linear-gradient(90deg, rgba(139,156,247,.55), rgba(217,119,87,.75))',
            }}
          />
          <span style={{ color: 'var(--accent)', whiteSpace: 'nowrap' }}>
            🌙 23:00
          </span>
          <div
            className="h-px flex-1"
            style={{
              background:
                'linear-gradient(90deg, rgba(217,119,87,.75), rgba(139,156,247,.55))',
            }}
          />
          <span style={{ color: 'var(--indigo-400)', whiteSpace: 'nowrap' }}>
            ↑ 07:00
          </span>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          {CARDS.map((card) => (
            <div
              key={card.title}
              style={{
                background: 'var(--surface-card)',
                border: `1px solid ${card.accent ? 'var(--border-accent)' : 'var(--border-default)'}`,
                padding: 24,
                boxShadow: card.accent ? 'var(--glow-accent)' : undefined,
              }}
            >
              <span
                className="font-mono uppercase"
                style={{
                  fontSize: 13,
                  letterSpacing: '0.14em',
                  color: card.eyebrowColor,
                }}
              >
                {card.eyebrow}
              </span>
              <h3
                style={{
                  fontSize: 20,
                  color: 'var(--moon-100)',
                  margin: '12px 0 10px',
                }}
              >
                {card.title}
              </h3>
              <p
                style={{
                  fontSize: 16,
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

        <p
          className="mx-auto text-center"
          style={{
            fontSize: 17,
            lineHeight: 1.6,
            color: 'var(--text-muted)',
            maxWidth: 680,
            margin: '28px auto 0',
          }}
        >
          You kept every decision. The plugin did the execution. Prefer to drive
          a stage yourself? Each one has a verb:{' '}
          <code style={{ color: 'var(--terra-400)' }}>/refine-issue</code>{' '}
          <code style={{ color: 'var(--terra-400)' }}>/spec</code>{' '}
          <code style={{ color: 'var(--terra-400)' }}>/impl</code>{' '}
          <code style={{ color: 'var(--terra-400)' }}>/review</code>.
        </p>
      </div>
    </section>
  );
}
