import {
  Eyebrow,
  InstallSnippet,
  Reveal,
  RevealGroup,
  Terminal,
} from '@nightshift-ai/ui';
import type { TerminalLine } from '@nightshift-ai/ui';

import { PipelineStrip } from './pipeline-strip';

const GITHUB_URL = 'https://github.com/whimzyLive/nightshift-ai';

// C3 — a conventional-commit example, typed on when scrolled into view.
// Excludes the page H1 (out of scope for any typewriter treatment).
const COMMIT_LINES: readonly TerminalLine[] = [
  { prompt: '$', text: 'git log -1 --oneline' },
  {
    text: 'a1b2c3d feat(auto): implement PROJ-142 — spec, plan, code, review',
    tone: 'success',
  },
];

// Verbatim from the design handoff (nightshift Landing.dc.html L236-280).
const STEPS: { step: string; runs: string; get: string }[] = [
  { step: '1', runs: 'PRD + spec', get: 'The ticket becomes a written spec' },
  {
    step: '2',
    runs: 'Plan',
    get: 'An implementation plan, reviewed before code',
  },
  {
    step: '3',
    runs: 'Implementation',
    get: 'Code written to the plan, on its own branch',
  },
  {
    step: '4',
    runs: 'QA review',
    get: 'Independent review by a different agent than the author',
  },
  {
    step: '5',
    runs: 'PR + ticket comment',
    get: 'A reviewed PR, with the paper trail linked back to the ticket',
  },
];

/**
 * How-it-works: eyebrow/header, static 5-stage strip, the reused
 * `/auto PROJ-142` install snippet, the 5-step lifecycle table, the
 * lightweight-threshold fast-path note (AC1), and the "drive a stage
 * yourself" note. Full-bleed `bg-void` band per the design's
 * `id="how-it-works"` section.
 */
export function HowItWorks() {
  return (
    <section
      id="how-it-works"
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen border-t ns-cv"
      style={{
        padding: '80px 28px',
        background: 'var(--bg-void)',
        borderColor: 'var(--border-default)',
      }}
    >
      <div className="mx-auto" style={{ maxWidth: 1000 }}>
        <RevealGroup className="mb-10 text-center">
          <Reveal>
            <Eyebrow>02 · how it works</Eyebrow>
          </Reveal>
          <Reveal
            as="h2"
            style={{
              fontSize: 'clamp(32px, 4vw, 46px)',
              letterSpacing: '-0.02em',
              color: 'var(--moon-100)',
              margin: '14px 0 14px',
            }}
          >
            One command runs the whole lifecycle
          </Reveal>
          <Reveal
            as="p"
            className="mx-auto"
            style={{
              fontSize: 18,
              lineHeight: 1.6,
              color: 'var(--text-muted)',
              maxWidth: 640,
            }}
          >
            Point it at a ticket. It triages the work, then runs each stage in
            order and closes the loop back to your tracker — spec before plan,
            plan before code, review before merge, tests as the gate.
          </Reveal>
        </RevealGroup>

        <PipelineStrip />

        <RevealGroup>
          <Reveal className="mx-auto mb-[22px]" style={{ maxWidth: 520 }}>
            <InstallSnippet command="/auto PROJ-142" />
          </Reveal>
        </RevealGroup>

        <RevealGroup>
          <Reveal
            className="border"
            style={{
              borderColor: 'var(--border-default)',
              background: 'var(--surface-card)',
              boxShadow: 'var(--elev-3), inset 0 1px 0 rgba(255,255,255,0.05)',
            }}
          >
            <div
              className="grid font-mono uppercase"
              style={{
                gridTemplateColumns: '56px 1.1fr 1.6fr',
                background: 'rgba(255,255,255,0.03)',
                borderBottom: '1px solid var(--border-default)',
                fontSize: 12,
                letterSpacing: '0.1em',
                color: 'var(--text-dim)',
              }}
            >
              <span style={{ padding: '12px 14px' }}>Step</span>
              <span style={{ padding: '12px 14px' }}>What runs</span>
              <span style={{ padding: '12px 14px' }}>What you get</span>
            </div>
            {STEPS.map((row, i) => (
              <div
                key={row.step}
                className="grid items-baseline"
                style={{
                  gridTemplateColumns: '56px 1.1fr 1.6fr',
                  borderBottom:
                    i < STEPS.length - 1
                      ? '1px solid var(--border-soft)'
                      : undefined,
                }}
              >
                <span
                  className="font-mono font-bold"
                  style={{ padding: 14, color: 'var(--accent)' }}
                >
                  {row.step}
                </span>
                <span
                  className="font-mono"
                  style={{
                    padding: 14,
                    fontSize: 14,
                    color: 'var(--moon-100)',
                  }}
                >
                  {row.runs}
                </span>
                <span
                  style={{
                    padding: 14,
                    fontSize: 16,
                    color: 'var(--text-body)',
                  }}
                >
                  {row.get}
                </span>
              </div>
            ))}
          </Reveal>
        </RevealGroup>

        <RevealGroup>
          <Reveal className="mx-auto mt-[22px]" style={{ maxWidth: 520 }}>
            <Terminal
              title="zsh — conventional commits"
              lines={COMMIT_LINES}
              revealOnView
              minHeight={88}
            />
          </Reveal>
        </RevealGroup>

        <RevealGroup>
          <Reveal className="mt-[22px] flex flex-wrap gap-3">
            <p
              data-lift
              className="flex-1"
              style={{
                minWidth: 260,
                fontSize: 14,
                lineHeight: 1.55,
                color: 'var(--text-muted)',
                margin: 0,
                background: 'var(--surface-card)',
                border: '1px solid var(--border-soft)',
                padding: '14px 16px',
                boxShadow:
                  'var(--elev-1), inset 0 1px 0 rgba(255,255,255,0.04)',
              }}
            >
              <span style={{ color: 'var(--moon-100)', fontWeight: 600 }}>
                /auto
              </span>{' '}
              triages by size. Stories at or under the lightweight threshold
              (default ≤3 points) skip the spec and plan and go straight to
              implementation.
            </p>
          </Reveal>

          <Reveal className="mt-3 flex flex-wrap gap-3">
            <p
              data-lift
              className="flex-1"
              style={{
                minWidth: 260,
                fontSize: 14,
                lineHeight: 1.55,
                color: 'var(--text-muted)',
                margin: 0,
                background: 'var(--surface-card)',
                border: '1px solid var(--border-soft)',
                padding: '14px 16px',
                boxShadow:
                  'var(--elev-1), inset 0 1px 0 rgba(255,255,255,0.04)',
              }}
            >
              <span style={{ color: 'var(--moon-100)', fontWeight: 600 }}>
                Drive a stage yourself.
              </span>{' '}
              Every stage has its own verb:{' '}
              <code style={{ color: 'var(--terra-400)' }}>/spec</code>{' '}
              <code style={{ color: 'var(--terra-400)' }}>/plan</code>{' '}
              <code style={{ color: 'var(--terra-400)' }}>/impl</code>{' '}
              <code style={{ color: 'var(--terra-400)' }}>/review</code>.
            </p>
          </Reveal>

          <Reveal className="mt-6 text-center">
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noopener"
              className="font-mono"
              style={{ fontSize: 14, color: 'var(--link)' }}
            >
              See the commands on GitHub →
            </a>
          </Reveal>
        </RevealGroup>
      </div>
    </section>
  );
}
