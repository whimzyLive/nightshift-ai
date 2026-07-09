/* nightshift marketing site — section components.
 * Composes design-system primitives from the bundle namespace.
 * Attached to window so index.html can mount them.
 */
const NS = window.NightshiftDesignSystem_983007;
const {
  Terminal,
  AgentCard,
  InstallSnippet,
  NavBar,
  Footer,
  Pipeline,
  Button,
  Badge,
} = NS;

const COLOR = (v) => `var(--${v})`;

/* ---------- Animated /auto pipeline terminal ---------- */
const PIPELINE_LINES = [
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

function AnimatedTerminal() {
  const [count, setCount] = React.useState(0);
  React.useEffect(() => {
    if (count >= PIPELINE_LINES.length) {
      const reset = setTimeout(() => setCount(0), 4200);
      return () => clearTimeout(reset);
    }
    const speed =
      PIPELINE_LINES[count] && PIPELINE_LINES[count].text === '' ? 120 : 520;
    const t = setTimeout(() => setCount((c) => c + 1), speed);
    return () => clearTimeout(t);
  }, [count]);
  return React.createElement(Terminal, {
    title: 'zsh — acme-api · claude code',
    minHeight: 360,
    lines: PIPELINE_LINES.slice(0, count),
  });
}

/* ---------- Hero ---------- */
function Hero() {
  return (
    <section
      style={{
        position: 'relative',
        overflow: 'hidden',
        padding: '88px 28px 72px',
      }}
    >
      <div className="ns-stars" />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          maxWidth: 'var(--container-max)',
          margin: '0 auto',
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 56,
          alignItems: 'center',
        }}
      >
        <div>
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 8,
              marginBottom: 22,
            }}
          >
            <Badge tone="accent" dot>
              v0.4.0 · MIT
            </Badge>
            <Badge tone="neutral">a Claude Code plugin</Badge>
          </span>
          <h1
            style={{
              fontSize: 'clamp(40px, 5.2vw, 60px)',
              lineHeight: 1.04,
              letterSpacing: '-0.025em',
              fontWeight: 800,
              color: COLOR('moon-100'),
              margin: '0 0 20px',
            }}
          >
            Your AI software team
            <br />
            that ships{' '}
            <span style={{ color: COLOR('accent') }}>while you sleep.</span>
          </h1>
          <p
            style={{
              fontSize: 18,
              lineHeight: 1.6,
              color: COLOR('text-muted'),
              maxWidth: 480,
              margin: '0 0 16px',
            }}
          >
            A Claude Code plugin that turns one terminal into a full
            software-delivery team — PM, architect, tech lead, engineers, QA —
            driven straight from your issue tracker.
          </p>
          <p
            style={{
              fontFamily: COLOR('font-mono'),
              fontSize: 14,
              color: COLOR('text-dim'),
              margin: '0 0 28px',
            }}
          >
            Jira ticket <span style={{ color: COLOR('indigo-400') }}>→</span>{' '}
            spec
            <span style={{ color: COLOR('indigo-400') }}> →</span> plan
            <span style={{ color: COLOR('indigo-400') }}> →</span> code
            <span style={{ color: COLOR('indigo-400') }}> →</span> review
            <span style={{ color: COLOR('indigo-400') }}> →</span> PR.
          </p>
          <div style={{ display: 'flex', gap: 12, marginBottom: 26 }}>
            <Button variant="primary" size="lg">
              Install in 60 seconds
            </Button>
            <Button variant="secondary" size="lg">
              Watch the demo
            </Button>
          </div>
          <InstallSnippet
            command="/plugin install sdlc@nightshift"
            prompt="$"
          />
        </div>
        <div style={{ position: 'relative' }}>
          <div className="ns-moon-glow" />
          <AnimatedTerminal />
        </div>
      </div>
    </section>
  );
}

/* ---------- Problem ---------- */
function Problem() {
  return (
    <section
      style={{
        padding: '72px 28px',
        borderTop: `1px solid ${COLOR('border-soft')}`,
      }}
    >
      <div style={{ maxWidth: 860, margin: '0 auto', textAlign: 'center' }}>
        <span className="ns-eyebrow">// The problem</span>
        <h2
          style={{
            fontSize: 'clamp(28px, 3.6vw, 40px)',
            lineHeight: 1.12,
            letterSpacing: '-0.02em',
            color: COLOR('moon-100'),
            margin: '18px 0 18px',
          }}
        >
          You don't lose time{' '}
          <span
            style={{
              color: COLOR('text-dim'),
              textDecoration: 'line-through',
              textDecorationColor: COLOR('moon-500'),
            }}
          >
            writing code
          </span>
          . You lose it in the{' '}
          <span style={{ color: COLOR('accent') }}>connective tissue</span>{' '}
          around it.
        </h2>
        <p
          style={{
            fontSize: 17,
            lineHeight: 1.65,
            color: COLOR('text-muted'),
            maxWidth: 660,
            margin: '0 auto',
          }}
        >
          Turning a vague ticket into a real spec. Breaking that spec into a
          plan. Keeping the plan honest while you implement. Then reviewing it
          without rubber-stamping your own work. AI assistants are great at the
          middle 20%. nightshift automates the other 80% — the{' '}
          <strong style={{ color: COLOR('moon-100') }}>process</strong>.
        </p>
      </div>
    </section>
  );
}

/* ---------- How it works ---------- */
const IDEAS = [
  {
    n: '01',
    title: 'A team, not a megaprompt',
    body: 'Each role is a separate agent with its own system prompt, tools, and memory. Narrow charters mean fewer hallucinations and cleaner handoffs — the same reason real teams specialize.',
  },
  {
    n: '02',
    title: 'Generic agents, per-repo config',
    body: 'The agents carry zero project specifics. Stack, owned paths, Jira key, base branch, quality gates — all live in one project-context.md the plugin auto-loads every session.',
  },
  {
    n: '03',
    title: 'The lifecycle is the product',
    body: "Spec → plan → implement → review isn't a suggestion; it's enforced by the commands and the handoff protocol. Tests are the merge gate. Reviews are done by a different agent than the one who wrote the code.",
  },
];

function HowItWorks() {
  return (
    <section
      style={{
        padding: '72px 28px',
        background: COLOR('bg-void'),
        borderTop: `1px solid ${COLOR('border-default')}`,
      }}
    >
      <div style={{ maxWidth: 'var(--container-max)', margin: '0 auto' }}>
        <div style={{ textAlign: 'center', marginBottom: 44 }}>
          <span className="ns-eyebrow">// How it works</span>
          <h2
            style={{
              fontSize: 'clamp(28px, 3.6vw, 40px)',
              letterSpacing: '-0.02em',
              color: COLOR('moon-100'),
              margin: '14px 0 0',
            }}
          >
            Three ideas do all the heavy lifting
          </h2>
        </div>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 18,
            marginBottom: 40,
          }}
        >
          {IDEAS.map((it) => (
            <div
              key={it.n}
              style={{
                background: COLOR('surface-card'),
                border: `1px solid ${COLOR('border-default')}`,
                borderRadius: 'var(--radius-lg)',
                padding: 26,
              }}
            >
              <span
                style={{
                  fontFamily: COLOR('font-mono'),
                  fontSize: 13,
                  fontWeight: 700,
                  color: COLOR('accent'),
                }}
              >
                {it.n}
              </span>
              <h3
                style={{
                  fontSize: 19,
                  color: COLOR('moon-100'),
                  margin: '14px 0 10px',
                }}
              >
                {it.title}
              </h3>
              <p
                style={{
                  fontSize: 14,
                  lineHeight: 1.6,
                  color: COLOR('text-muted'),
                  margin: 0,
                }}
              >
                {it.body}
              </p>
            </div>
          ))}
        </div>
        <Pipeline
          stages={[
            {
              command: '/spec',
              label: 'Technical spec',
              agent: 'solutions-architect',
              status: 'done',
            },
            {
              command: '/plan',
              label: 'Ordered plan',
              agent: 'tech-lead',
              status: 'done',
            },
            {
              command: '/impl',
              label: 'Implementation',
              agent: 'principal-engineer',
              status: 'active',
            },
            {
              command: '/review',
              label: 'Quality gate',
              agent: 'qa-engineer',
              status: 'idle',
            },
            { command: 'PR', label: 'Ship it', agent: 'auto', status: 'idle' },
          ]}
        />
      </div>
    </section>
  );
}

/* ---------- Meet your team (11 agents) ---------- */
const TEAM = [
  {
    name: 'product-manager',
    owns: 'Vague idea → PRD with binary acceptance criteria',
    tone: 'accent',
  },
  {
    name: 'solutions-architect',
    owns: 'PRD → technical design / spec',
    tone: 'accent',
  },
  {
    name: 'scrum-master',
    owns: 'Story slicing, mapping, splitting',
    tone: 'info',
  },
  {
    name: 'tech-lead',
    owns: 'Spec → ordered, verifiable implementation plan',
    tone: 'info',
  },
  {
    name: 'principal-engineer',
    owns: 'Orchestrates the build, dispatches domain agents in dependency order',
    tone: 'accent',
  },
  {
    name: 'platform-engineer',
    owns: 'Backend / infrastructure / serverless',
    tone: 'cyan',
  },
  { name: 'web-engineer', owns: 'Web UI', tone: 'cyan' },
  { name: 'mobile-engineer', owns: 'Mobile apps', tone: 'cyan', standby: true },
  {
    name: 'database-administrator',
    owns: 'Schema, migrations, data',
    tone: 'cyan',
  },
  {
    name: 'sync-engineer',
    owns: 'Offline / sync layer',
    tone: 'cyan',
    standby: true,
  },
  {
    name: 'qa-engineer',
    owns: 'Always-on review → quality gate → AC verification → PR',
    tone: 'green',
  },
];

function Team() {
  return (
    <section
      style={{
        padding: '72px 28px',
        borderTop: `1px solid ${COLOR('border-default')}`,
      }}
    >
      <div style={{ maxWidth: 'var(--container-max)', margin: '0 auto' }}>
        <div style={{ textAlign: 'center', marginBottom: 44 }}>
          <span className="ns-eyebrow">// Meet your team</span>
          <h2
            style={{
              fontSize: 'clamp(28px, 3.6vw, 40px)',
              letterSpacing: '-0.02em',
              color: COLOR('moon-100'),
              margin: '14px 0 12px',
            }}
          >
            Eleven specialists, one terminal
          </h2>
          <p style={{ fontSize: 15, color: COLOR('text-muted'), margin: 0 }}>
            Standby roles activate only when your project-context.md says your
            project has them.
          </p>
        </div>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(248px, 1fr))',
            gap: 14,
          }}
        >
          {TEAM.map((a) => (
            <AgentCard key={a.name} {...a} />
          ))}
        </div>
      </div>
    </section>
  );
}

/* ---------- Install ---------- */
function Install() {
  return (
    <section
      style={{
        padding: '80px 28px',
        background: COLOR('bg-void'),
        borderTop: `1px solid ${COLOR('border-default')}`,
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      <div
        className="ns-moon-glow"
        style={{ top: '-120px', right: '-80px', left: 'auto' }}
      />
      <div
        style={{
          position: 'relative',
          zIndex: 1,
          maxWidth: 720,
          margin: '0 auto',
          textAlign: 'center',
        }}
      >
        <span className="ns-eyebrow">// Install in 60 seconds</span>
        <h2
          style={{
            fontSize: 'clamp(28px, 3.6vw, 40px)',
            letterSpacing: '-0.02em',
            color: COLOR('moon-100'),
            margin: '14px 0 28px',
          }}
        >
          Two lines in any Claude Code session
        </h2>
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 12,
            textAlign: 'left',
          }}
        >
          <InstallSnippet
            command="/plugin marketplace add whimzyLive/nightshift-ai"
            prompt="$"
          />
          <InstallSnippet
            command="/plugin install sdlc@nightshift"
            prompt="$"
          />
        </div>
        <p style={{ fontSize: 14, color: COLOR('text-dim'), marginTop: 22 }}>
          That's it. The shared workflow skills it depends on install
          automatically.
        </p>
      </div>
    </section>
  );
}

window.MarketingSections = {
  Hero,
  Problem,
  HowItWorks,
  Team,
  Install,
  NavBar,
  Footer,
};
