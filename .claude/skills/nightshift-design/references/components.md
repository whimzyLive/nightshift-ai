# nightshift — component API reference

13 React components, namespace `window.NightshiftDesignSystem_983007`. Each has a `.d.ts` (types) + `.prompt.md` (usage) + group `*.card.html` specimen in `components/`. **Prefer these components over hand-rolled markup** — they bake in the tokens, hairlines, glow, and motion. Hand-build only what isn't covered, and then follow `references/patterns.md`.

Defaults are marked. Don't restate a default; only pass props that differ.

---

## core/

### Button
Primary action primitive, terracotta + dark-native. Reach for `mono` when the label is a command.
```jsx
<Button variant="primary" size="md">Install plugin</Button>
<Button variant="secondary" iconLeft={<GitHubIcon/>}>Star on GitHub</Button>
<Button variant="ghost" mono>/auto</Button>
<Button variant="primary" loading>Running…</Button>
```
- `variant`: `primary` (filled terracotta + `--glow-accent`) · `secondary` (raised surface + hairline) · `ghost` (text, fills on hover) · `danger` (red outline). **@default primary**
- `size`: `sm | md | lg`. @default md
- `mono` bool (command labels) · `loading` bool (spinner, blocks) · `disabled` · `iconLeft`/`iconRight` nodes · `fullWidth` · `onClick` · `type: button|submit|reset`
- Hover lifts `translateY(-1px)`; primary press → `--accent-press`.

### Badge
Status / metadata pill, **monospace by default** (terminal texture). Agent states, ticket status, version tags.
```jsx
<Badge tone="success" dot>passing</Badge>
<Badge tone="accent">v0.4.0</Badge>
<Badge tone="warning" dot>pending review</Badge>
<Badge tone="info" solid>PR #142</Badge>
```
- `tone`: `neutral | accent | info | success | warning | danger`. @default neutral
- `dot` bool (leading status dot) · `solid` bool (filled vs tinted) · `mono` bool **@default true** · `size: sm|md` @default md

### Card
Base surface container — `--surface-card` fill, hairline border, deep soft shadow. The structural primitive most blocks sit inside.
```jsx
<Card>…</Card>
<Card glow>Featured / hero card with accent ring</Card>
<Card interactive onClick={…}>Clickable card with hover lift</Card>
```
- `glow` bool (accent ring + lift — featured) · `interactive` bool (hover elevation) · `padding` px @default 24 · `as` element tag · `style`
- **Always keeps the hairline border** — required on dark.

### InstallSnippet
Copy-to-clipboard command line — the "install in 60 seconds" affordance. Terminal-well, accent border on hover, copy flips to `copied ✓` (green ~1.6s).
```jsx
<InstallSnippet label="Install in 60 seconds" />
<InstallSnippet command="/plugin marketplace add whimzyLive/nightshift-ai" prompt="$" />
```
- `command` @default `/plugin install sdlc@nightshift` · `prompt` @default `$` · `label` optional uppercase mono caption

---

## terminal/ — the signature surfaces

### Terminal (+ TermLine)
Terminal window frame — macOS traffic lights, centered title, dark output body (`--surface-terminal`). **The brand's hero surface.** Show real `/auto` pipeline output.
```jsx
<Terminal title="zsh — acme-api" lines={[
  { prompt: '$', text: '/auto PROJ-142' },
  { agent: 'product-manager', text: '→ reads the ticket, writes a PRD', tone: 'accent' },
  { agent: 'qa-engineer', text: '→ quality gate passed', tone: 'success' },
]} />
```
- `title` @default `zsh — nightshift` · `lines`: `(string | TermLineSpec)[]` · `children` (custom, instead of lines) · `showDot` · `minHeight` · `style`
- `TermLineSpec`: `{ text, tone, prompt, agent, indent, dim }`
- tones: `default · success · warning · danger · info · muted · accent`

### CodeBlock
Code surface with filename header + copy button. Built-in tinting for shell prompts (`$ >`), comments, Conventional Commit prefixes (`feat(scope):`). No external highlighter.
```jsx
<CodeBlock filename=".claude/project/project-context.md" language="markdown" code={`...`} />
<CodeBlock language="bash" code={'$ /plugin install sdlc@nightshift'} showLineNumbers />
```
- `code` · `language` @default bash · `filename` · `showLineNumbers` · `copyable` @default true

### Pipeline
The lifecycle as connected blocks — spec → plan → impl → review → PR. Connectors turn green as stages complete.
```jsx
<Pipeline stages={[
  { command: '/spec', label: 'Technical spec', agent: 'solutions-architect', status: 'done' },
  { command: '/plan', label: 'Ordered plan', agent: 'tech-lead', status: 'active' },
  { command: '/impl', label: 'Implementation', agent: 'principal-engineer' },
  { command: '/review', label: 'Quality gate', agent: 'qa-engineer' },
]} />
```
- `stages`: `{command, label?, agent?, status?}[]` · status `idle | active | done` (@default idle; active gets `--glow-accent`, done a green check) · `orientation: horizontal | vertical` @default horizontal

---

## site/

### NavBar
Sticky top nav — logo lockup, links, GitHub-stars pill, primary CTA. Translucent night backdrop + blur.
```jsx
<NavBar links={[{label:'How it works'},{label:'The team'},{label:'Docs'},{label:'Pricing'}]}
  active="Docs" stars="1.2k" ctaLabel="Install" />
```
- `links`: `{label, href?}[]` · `active` (active link label) · `stars` @default `1.2k` · `ctaLabel`/`onCta` · `logoSrc` · `brand`
- **Set `logoSrc` to the correct relative path to `assets/logomark.svg` from your page.**

### Footer
Brand lockup + tagline left, column nav right, fine print beneath. Sits on deepest `--bg-void` (page floor).
```jsx
<Footer columns={[
  { title: 'Product', items: ['How it works', 'The team', 'Commands'] },
  { title: 'Docs', items: ['Quickstart', 'Configure', 'Extend'] },
  { title: 'Community', items: ['GitHub', 'Discord', 'Changelog'] },
]} />
```
- `columns`: `{title, items[]}[]` · `tagline` · `bottomNote` · `builtOn` · `logoSrc`

---

## data/

### AgentCard
A role in the AI team — mono name, monogram avatar, what it owns. Builds the "meet your team" grid.
```jsx
<AgentCard name="product-manager" owns="Vague idea → PRD with binary acceptance criteria" tone="accent" />
<AgentCard name="qa-engineer" owns="Always-on review → quality gate → AC verification → PR" tone="green" status="active" />
<AgentCard name="mobile-engineer" owns="Mobile apps" standby />
```
- `name` · `owns` (one line) · `glyph` (override auto monogram) · `tone: accent | info | cyan | green` @default accent · `status` (colored status line) · `standby` bool (dims conditional roles)

### CommandCard
Slash-command reference entry — command, arg signature, description, dispatched agents. Accent border on hover.
```jsx
<CommandCard command="/auto" args="<TICKET>"
  description="The whole pipeline, end to end — ticket in, reviewed PR out."
  agents={['product-manager','solutions-architect','tech-lead','qa-engineer']} />
<CommandCard command="/spec"
  description="Produce the technical design spec for a story."
  agents={['solutions-architect']} output="docs/superpowers/specs/PROJ-142.md" />
```
- `command` · `args` · `description` (required) · `agents[]` · `output`

### Table
Quiet data table — mono headers, hairline rows, hover highlight.
```jsx
<Table columns={[
  { key: 'cmd', header: 'Command', mono: true },
  { key: 'does', header: 'What it does' },
]} rows={[{ cmd: '/auto', does: 'Full pipeline' }]} />
```
- `columns`: `{key, header, align?, mono?, muted?}[]` · `rows`: objects keyed by `column.key` (values = string | node) · `dense` bool

---

## Product data (for marketing/docs copy)

**The team — agents** (one per SDLC role): `product-manager`, `solutions-architect`, `tech-lead`, `principal-engineer`, `web-engineer`, `mobile-engineer`, `platform-engineer`, `sync-engineer`, `qa-engineer`, `scrum-master` (+ more conditional roles — 11 total). Name agents in lowercase mono.

**Commands** (run the lifecycle one verb at a time): `/spec`, `/plan`, `/impl`, `/review`, and one-shot `/auto <TICKET>` (10 total). Install: `/plugin install sdlc@nightshift` or `/plugin marketplace add whimzyLive/nightshift-ai`.
