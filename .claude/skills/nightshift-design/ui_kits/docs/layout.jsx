/* nightshift docs home — layout components.
 * Sidebar nav, content prose, command reference grid.
 */
const NSd = window.NightshiftDesignSystem_983007;
const { CommandCard, CodeBlock, Badge, Table, InstallSnippet, Button } = NSd;
const C = (v) => `var(--${v})`;

const NAV = [
  { group: 'Getting started', items: ['Overview', 'Install', 'Quickstart', 'Project context'] },
  { group: 'Commands', items: ['/auto', '/spec', '/plan', '/impl', '/review'] },
  { group: 'The team', items: ['Agents overview', 'Handoff protocol', 'Standby roles'] },
  { group: 'Extend', items: ['Add a skill', 'Bind to a role', 'Adapters'] },
];

function Sidebar({ active = 'Overview' }) {
  return (
    <aside style={{
      width: 248, flex: 'none', borderRight: `1px solid ${C('border-default')}`,
      padding: '28px 18px', position: 'sticky', top: 'var(--nav-height)',
      height: 'calc(100vh - var(--nav-height))', overflowY: 'auto', boxSizing: 'border-box',
      background: C('bg-page'),
    }}>
      <div style={{ position: 'relative', marginBottom: 20 }}>
        <input placeholder="Search docs…" readOnly style={{
          width: '100%', boxSizing: 'border-box', background: C('surface-terminal'),
          border: `1px solid ${C('border-default')}`, borderRadius: 'var(--radius-md)',
          padding: '8px 12px 8px 32px', color: C('text-muted'),
          fontFamily: C('font-mono'), fontSize: 12,
        }} />
        <span style={{ position: 'absolute', left: 11, top: 8, color: C('text-dim'), fontSize: 13 }}>⌕</span>
        <span style={{ position: 'absolute', right: 10, top: 7, fontFamily: C('font-mono'), fontSize: 10,
          color: C('text-dim'), border: `1px solid ${C('border-default')}`, borderRadius: 4, padding: '1px 5px' }}>⌘K</span>
      </div>
      {NAV.map((sec) => (
        <div key={sec.group} style={{ marginBottom: 22 }}>
          <div style={{ fontFamily: C('font-mono'), fontSize: 11, letterSpacing: '0.12em',
            textTransform: 'uppercase', color: C('text-dim'), marginBottom: 8, paddingLeft: 10 }}>{sec.group}</div>
          {sec.items.map((it) => {
            const on = it === active;
            const mono = it.startsWith('/');
            return (
              <a key={it} href="#" style={{
                display: 'block', padding: '6px 10px', borderRadius: 'var(--radius-sm)',
                fontFamily: mono ? C('font-mono') : C('font-sans'), fontSize: 13.5,
                color: on ? C('terra-400') : C('text-muted'),
                background: on ? C('terra-tint') : 'transparent',
                textDecoration: 'none', marginBottom: 1,
                borderLeft: on ? `2px solid ${C('accent')}` : '2px solid transparent',
              }}>{it}</a>
            );
          })}
        </div>
      ))}
    </aside>
  );
}

function Content() {
  return (
    <main style={{ flex: 1, minWidth: 0, padding: '40px 48px 80px', maxWidth: 880 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontFamily: C('font-mono'), fontSize: 12, color: C('text-dim'), marginBottom: 18 }}>
        <span>Docs</span><span>/</span><span>Getting started</span><span>/</span><span style={{ color: C('text-muted') }}>Overview</span>
      </div>
      <span className="ns-eyebrow">// sdlc plugin</span>
      <h1 style={{ fontSize: 40, letterSpacing: '-0.025em', color: C('moon-100'), margin: '12px 0 16px' }}>Overview</h1>
      <p style={{ fontSize: 17, lineHeight: 1.65, color: C('text-body'), margin: '0 0 14px' }}>
        nightshift installs a repo-agnostic software-delivery team into Claude Code. Its flagship plugin,
        <code style={{ fontFamily: C('font-mono'), color: C('terra-400'), background: C('terra-tint'), padding: '1px 6px', borderRadius: 4, margin: '0 4px' }}>sdlc</code>,
        gives you 11 specialized agents and 10 slash commands — the whole lifecycle, one verb at a time.
      </p>
      <p style={{ fontSize: 15, lineHeight: 1.65, color: C('text-muted'), margin: '0 0 28px' }}>
        It is <strong style={{ color: C('moon-100') }}>not</strong> a wrapper that writes code for you. It's a
        process engine that makes a senior team's discipline the default — spec before plan, plan before code,
        review before merge, tests as the gate.
      </p>

      <div style={{ display: 'flex', gap: 10, marginBottom: 36 }}>
        <Badge tone="success" dot>repo-agnostic</Badge>
        <Badge tone="info">11 agents</Badge>
        <Badge tone="accent">10 commands</Badge>
        <Badge tone="neutral">MIT</Badge>
      </div>

      <h2 style={{ fontSize: 24, letterSpacing: '-0.01em', color: C('moon-100'), margin: '0 0 14px', paddingBottom: 10, borderBottom: `1px solid ${C('border-soft')}` }}>Install in 60 seconds</h2>
      <p style={{ fontSize: 15, lineHeight: 1.6, color: C('text-muted'), margin: '0 0 16px' }}>In any Claude Code session:</p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 36 }}>
        <InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" prompt="$" />
        <InstallSnippet command="/plugin install sdlc@nightshift" prompt="$" />
      </div>

      <h2 style={{ fontSize: 24, letterSpacing: '-0.01em', color: C('moon-100'), margin: '0 0 18px', paddingBottom: 10, borderBottom: `1px solid ${C('border-soft')}` }}>Command reference</h2>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 36 }}>
        <CommandCard command="/auto" args="<TICKET>" description="The whole pipeline, end to end — ticket in, reviewed PR out." agents={['product-manager','solutions-architect','tech-lead','principal-engineer','qa-engineer']} />
        <CommandCard command="/spec" description="Produce the technical design spec for a story. Creates a branch, writes the spec doc, raises a PR." agents={['solutions-architect']} output="docs/superpowers/specs/PROJ-142.md" />
        <CommandCard command="/plan" description="Break the spec into an ordered, verifiable implementation plan." agents={['tech-lead']} />
        <CommandCard command="/impl" description="Execute the plan with domain agents in dependency order." agents={['principal-engineer','platform-engineer']} />
        <CommandCard command="/review" args="" description="Review against the spec, run the quality gate, verify acceptance criteria." agents={['qa-engineer']} />
      </div>

      <h2 style={{ fontSize: 24, letterSpacing: '-0.01em', color: C('moon-100'), margin: '0 0 16px', paddingBottom: 10, borderBottom: `1px solid ${C('border-soft')}` }}>Configure your repo</h2>
      <p style={{ fontSize: 15, lineHeight: 1.6, color: C('text-muted'), margin: '0 0 16px' }}>
        Each consuming repo supplies one file — <code style={{ fontFamily: C('font-mono'), color: C('indigo-400') }}>.claude/project/project-context.md</code> — declaring its constants.
      </p>
      <CodeBlock filename=".claude/project/project-context.md" language="markdown" code={
`# Project Context

| Token            | Value                      |
| ---------------- | -------------------------- |
| Project name     | acme-api                   |
| Jira project key | ACME                       |
| Base branch      | develop                    |
| Package manager  | pnpm                       |
| Typecheck / Test | pnpm typecheck / pnpm test |

## Workspace -> agent
| Path           | Owner             |
| -------------- | ----------------- |
| services/api/  | platform-engineer |
| apps/web/      | web-engineer      |`} />
    </main>
  );
}

function OnThisPage() {
  const items = ['Install in 60 seconds', 'Command reference', 'Configure your repo'];
  return (
    <aside style={{ width: 200, flex: 'none', padding: '40px 20px', position: 'sticky', top: 'var(--nav-height)',
      height: 'calc(100vh - var(--nav-height))', boxSizing: 'border-box' }}>
      <div style={{ fontFamily: C('font-mono'), fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: C('text-dim'), marginBottom: 12 }}>On this page</div>
      {items.map((it, i) => (
        <a key={it} href="#" style={{ display: 'block', fontSize: 13, color: i === 0 ? C('terra-400') : C('text-muted'),
          textDecoration: 'none', padding: '5px 0', lineHeight: 1.4 }}>{it}</a>
      ))}
    </aside>
  );
}

window.DocsLayout = { Sidebar, Content, OnThisPage };
