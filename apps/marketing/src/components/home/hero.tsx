import { Badge, CtaButton, InstallSnippet, Terminal } from '@nightshift-ai/ui';
import type { TerminalLine } from '@nightshift-ai/ui';

const GITHUB_URL = 'https://github.com/whimzyLive/nightshift-ai';

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
      style={{ padding: '92px 0 76px' }}
    >
      <div
        className="relative z-[1] mx-auto grid grid-cols-1 items-center gap-12 md:grid-cols-[1fr_1.12fr]"
        style={{ maxWidth: 'var(--container-max)' }}
      >
        <div>
          <span className="mb-[22px] inline-flex items-center gap-2">
            <Badge variant="accent" dot>
              v0.4.0 · MIT
            </Badge>
            <Badge variant="neutral">a Claude Code plugin</Badge>
          </span>
          <h1
            className="font-sans font-extrabold"
            style={{
              fontSize: 'var(--display-clamp-hero)',
              lineHeight: 1.04,
              letterSpacing: '-0.025em',
              color: 'var(--moon-100)',
              margin: '0 0 20px',
            }}
          >
            Your AI software team that ships{' '}
            <a href="#workflow" style={{ color: 'var(--accent)' }}>
              while you sleep
            </a>
          </h1>
          <p
            style={{
              fontSize: 20,
              lineHeight: 1.6,
              color: 'var(--text-muted)',
              maxWidth: 500,
              margin: '0 0 16px',
            }}
          >
            A Claude Code plugin that turns one terminal into a full delivery
            team — product manager, architect, tech lead, engineers, and QA. It
            reads a Jira ticket and ships the spec, plan, code, and review.
          </p>
          <p
            className="font-mono"
            style={{
              fontSize: 16,
              color: 'var(--text-dim)',
              margin: '0 0 28px',
            }}
          >
            Jira ticket <span style={{ color: 'var(--indigo-400)' }}>→</span>{' '}
            spec <span style={{ color: 'var(--indigo-400)' }}>→</span> plan{' '}
            <span style={{ color: 'var(--indigo-400)' }}>→</span> implementation{' '}
            <span style={{ color: 'var(--indigo-400)' }}>→</span> review{' '}
            <span style={{ color: 'var(--indigo-400)' }}>→</span> PR
          </p>
          <div className="flex flex-col gap-[10px]" style={{ maxWidth: 520 }}>
            <span
              className="font-mono uppercase"
              style={{
                fontSize: 13,
                letterSpacing: '0.14em',
                color: 'var(--text-dim)',
              }}
            >
              Install in 60 seconds
            </span>
            <InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" />
            <InstallSnippet command="/plugin install sdlc@nightshift" />
          </div>
          <div className="mt-[22px] flex gap-3">
            <CtaButton href={GITHUB_URL} target="_blank" rel="noopener">
              ★ Star nightshift on GitHub
            </CtaButton>
          </div>
        </div>
        <div className="relative">
          <div
            aria-hidden="true"
            className="pointer-events-none absolute rounded-full blur-[10px]"
            style={{
              top: -70,
              left: -50,
              width: 420,
              height: 420,
              background:
                'radial-gradient(circle, var(--terra-glow), transparent 62%)',
            }}
          />
          <Terminal
            title="zsh — acme-api · claude code"
            lines={TERMINAL_LINES}
            minHeight={420}
          />
        </div>
      </div>
    </section>
  );
}
