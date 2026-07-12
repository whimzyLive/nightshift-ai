import { Badge, InstallSnippet, Terminal } from '@nightshift-ai/ui';
import type { TerminalLine } from '@nightshift-ai/ui';

// Verbatim from the design handoff (nightshift Landing.dc.html L725-738,
// LINES) — the scripted /auto PROJ-142 run the Terminal loops through.
const TERMINAL_LINES: TerminalLine[] = [
  { prompt: '$', text: '/auto PROJ-142' },
  { text: '' },
  { text: 'Reading ticket PROJ-142 from Jira…', tone: 'muted' },
  {
    agent: 'product-manager',
    text: '→ wrote PRD · 4 acceptance criteria',
    tone: 'accent',
  },
  {
    agent: 'solutions-architect',
    text: '→ technical spec · 2 new endpoints',
    tone: 'accent',
  },
  {
    agent: 'tech-lead',
    text: '→ ordered plan · 7 verifiable steps',
    tone: 'accent',
  },
  {
    agent: 'principal-engineer',
    text: '→ dispatching domain engineers…',
    tone: 'accent',
  },
  {
    text: 'platform-engineer  ✓ implemented, 142 tests green',
    tone: 'muted',
    indent: 1,
  },
  {
    text: 'web-engineer       ✓ UI wired, a11y pass',
    tone: 'muted',
    indent: 1,
  },
  {
    agent: 'qa-engineer',
    text: '→ quality gate passed · ACs verified',
    tone: 'success',
  },
  { text: '→ opened PR #318 · commented on PROJ-142', tone: 'success' },
  { prompt: '$', text: '▌', tone: 'accent' },
];

/**
 * Above-the-fold hero: value line, install snippets, GitHub star CTA, and
 * the scripted Terminal preview. Server component — the client boundary
 * lives only inside InstallSnippet/Terminal.
 */
export function Hero() {
  return (
    <section
      className="relative overflow-hidden"
      style={{
        padding: 'clamp(1.25rem, 4.5vh, 5.75rem) 0 clamp(1rem, 3.5vh, 4.75rem)',
      }}
    >
      <div
        className="relative z-[1] mx-auto grid grid-cols-1 items-center gap-x-12 gap-y-8 md:grid-cols-[1fr_1.12fr]"
        style={{ maxWidth: 'var(--container-max)' }}
      >
        <div>
          <span
            className="inline-flex items-center gap-2"
            style={{ marginBottom: 'clamp(0.625rem, 2.2vh, 1.75rem)' }}
          >
            <Badge variant="accent" dot>
              v0.4.0 · MIT
            </Badge>
            <Badge variant="neutral">a Claude Code plugin</Badge>
          </span>
          <h1
            className="font-sans font-extrabold"
            style={{
              // Cap the hero display by viewport *height* too, so short
              // laptops shrink it enough to keep the whole fold on screen.
              fontSize: 'min(var(--display-clamp-hero), 6.6vh)',
              lineHeight: 1.04,
              letterSpacing: '-0.025em',
              color: 'var(--moon-100)',
              margin: '0 0 clamp(0.75rem, 2.2vh, 1.75rem)',
            }}
          >
            Your AI software team that ships{' '}
            <a href="#workflow" style={{ color: 'var(--accent)' }}>
              while you sleep
            </a>
          </h1>
          <p
            style={{
              fontSize: 'clamp(0.9375rem, 2.2vh, 1.25rem)',
              lineHeight: 1.7,
              color: 'var(--text-muted)',
              maxWidth: '31.25rem',
              margin: '0 0 clamp(0.75rem, 2.4vh, 1.75rem)',
            }}
          >
            A Claude Code plugin that turns one terminal into a full delivery
            team — product manager, architect, tech lead, engineers, and QA. It
            reads a Jira ticket and ships the spec, plan, code, and review.
          </p>
          {/* Lifecycle line styled as the neon button's hover state — the
              `--shadow-pop` stacked terracotta layers + `--glow-neon-hover`
              glow, lifting on hover exactly like ★ Star on GitHub. */}
          <p
            className="relative inline-block font-mono whitespace-nowrap transition-[transform,box-shadow] duration-200 ease-out hover:-translate-y-0.5 motion-reduce:transition-none"
            style={{
              margin: '0 0 clamp(1rem, 3vh, 2.75rem)',
              padding: 'clamp(0.6875rem, 1.6vh, 0.9375rem) 1.125rem',
              fontSize: 'clamp(0.6875rem, 1.5vh, 0.8125rem)',
              color: 'var(--btn-neon-hover-text)',
              background: 'var(--btn-neon-hover-bg)',
              boxShadow: 'var(--glow-neon-hover), var(--shadow-pop)',
            }}
          >
            Ticket <span style={{ color: 'rgba(245,243,239,0.7)' }}>→</span>{' '}
            Specs <span style={{ color: 'rgba(245,243,239,0.7)' }}>→</span> Plan{' '}
            <span style={{ color: 'rgba(245,243,239,0.7)' }}>→</span>{' '}
            Implementation{' '}
            <span style={{ color: 'rgba(245,243,239,0.7)' }}>→</span> Review{' '}
            <span style={{ color: 'rgba(245,243,239,0.7)' }}>→</span> PR
          </p>
          <div
            className="flex flex-col"
            style={{
              maxWidth: '32.5rem',
              gap: 'clamp(0.375rem, 1vh, 0.625rem)',
            }}
          >
            <span
              className="font-mono uppercase"
              style={{
                fontSize: '0.8125rem',
                letterSpacing: '0.14em',
                color: 'var(--text-dim)',
              }}
            >
              Install in 60 seconds
            </span>
            <InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" />
            <InstallSnippet command="/plugin install sdlc@nightshift" />
          </div>
        </div>
        <div className="relative">
          <div
            aria-hidden="true"
            className="pointer-events-none absolute rounded-full blur-[60px]"
            style={{
              top: '-7rem',
              left: '-6rem',
              width: '32rem',
              height: '32rem',
              background:
                'radial-gradient(circle, var(--terra-glow), transparent 66%)',
            }}
          />
          <Terminal
            title="zsh — acme-api · claude code"
            lines={TERMINAL_LINES}
            minHeight="clamp(16.25rem, 40vh, 26.25rem)"
          />
        </div>
      </div>
    </section>
  );
}
