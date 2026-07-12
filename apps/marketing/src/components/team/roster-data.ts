// Verbatim from the design handoff (team.dc.html renderVals().depts, L285-412)
// plus the philosophy cards (L110-126) and handbook steps (L188-193). Tier
// facts cross-checked against the real `model:` frontmatter in
// plugins/sdlc/agents/*.md (see NA-37 plan Task 1, Step 4).

export type ModelTier = 'human' | 'opus' | 'sonnet';

export interface AgentProfile {
  /** Two/three-letter mono initials, e.g. 'SA', 'YOU'. */
  ini: string;
  /** Agent file stem / roster name, e.g. 'solutions-architect'. */
  name: string;
  /** Human job title, e.g. 'Solutions Architect'. */
  title: string;
  /** Model tier — drives the badge label + color. */
  tier: ModelTier;
  /** Optional badge text override (unused today; keep for parity with design). */
  badgeOverride?: string;
  /** Charter summary shown as the card body. */
  owns: string;
  /** Sequence/handoff line, e.g. 'after: scrum-master · hands to: tech-lead'. */
  flow: string;
  /** Artifact produced, e.g. 'docs/superpowers/specs/<KEY>.md'. */
  artifact: string;
  /** One-liner personality fact. */
  fact: string;
  /**
   * Agent charter file name under plugins/sdlc/agents/, e.g.
   * 'solutions-architect.md'. `null` for the human (no charter file).
   */
  file: string | null;
}

export interface Department {
  /** Mono eyebrow, e.g. '// product'. */
  eyebrow: string;
  /** Display title, e.g. 'Product'. */
  title: string;
  /** Cluster description line. */
  blurb: string;
  members: AgentProfile[];
}

export const YOU: AgentProfile = {
  ini: 'YOU',
  name: 'you',
  title: 'Head of Everything',
  tier: 'human',
  owns: 'Refines stories by day, approves what is ready, and reviews the PRs in the morning. Sets the routing config and the approval mode — the whole org runs on this sign-off.',
  flow: 'reads: everything · reports to: no one',
  artifact: 'decisions',
  fact: 'The only member who sleeps. The org is built around that.',
  file: null,
};

export const DEPARTMENTS: Department[] = [
  {
    eyebrow: '// product',
    title: 'Product',
    blurb:
      'Turns vague ideas into unambiguous, buildable work — in product language only. No entity names, no API paths.',
    members: [
      {
        ini: 'PM',
        name: 'product-manager',
        title: 'Product Manager',
        tier: 'opus',
        owns: 'Converts a vague feature idea into a full PRD — problem statement, personas, user stories, binary acceptance criteria, success metrics, out-of-scope boundaries.',
        flow: 'runs first · hands to: solutions-architect',
        artifact: 'docs/features/<date>-<slug>.md',
        fact: 'If your idea is under two sentences, expect exactly one clarifying question.',
        file: 'product-manager.md',
      },
      {
        ini: 'SM',
        name: 'scrum-master',
        title: 'Scrum Master',
        tier: 'sonnet',
        owns: 'Two modes: decomposes an approved Epic into dependency-ordered Jira stories, or triages a rough stakeholder ticket into a well-formed story in place.',
        flow: 'after: product-manager · hands to: solutions-architect',
        artifact: 'ordered, well-formed stories',
        fact: 'Fixes your tickets without complaining about them in standup.',
        file: 'scrum-master.md',
      },
    ],
  },
  {
    eyebrow: '// architecture + planning',
    title: 'Architecture & Planning',
    blurb:
      'Where WHAT gets decided before any HOW. Specs with no TBDs, plans with no task spanning two agents.',
    members: [
      {
        ini: 'SA',
        name: 'solutions-architect',
        title: 'Solutions Architect',
        tier: 'opus',
        owns: 'Converts an approved story into a complete technical spec — data model, API surface, permission matrix, sync rules. Jira is the only product context it will accept.',
        flow: 'after: scrum-master · hands to: tech-lead',
        artifact: 'docs/superpowers/specs/<KEY>.md',
        fact: 'A finished spec may not contain the letters T, B, D in that order.',
        file: 'solutions-architect.md',
      },
      {
        ini: 'TL',
        name: 'tech-lead',
        title: 'Tech Lead',
        tier: 'opus',
        owns: 'Breaks the spec into concrete, ordered, agent-tagged tasks — schema first, review last — each phase ending in a verification step with real gate commands.',
        flow: 'after: solutions-architect · hands to: principal-engineer',
        artifact: 'docs/superpowers/plans/<KEY>.md',
        fact: 'No task may span two agents. If it touches two domains, it gets split.',
        file: 'tech-lead.md',
      },
    ],
  },
  {
    eyebrow: '// engineering',
    title: 'Engineering',
    blurb:
      'One orchestrator, five domain specialists. Sequential by design — never two agents on the branch at once, and each touches only the paths it owns.',
    members: [
      {
        ini: 'PE',
        name: 'principal-engineer',
        title: 'Principal Engineer · orchestrates',
        tier: 'opus',
        owns: 'Executes the plan: dispatches domain agents in strict dependency order on the shared story branch, pushes their commits, and opens the PR once QA returns clean.',
        flow: 'after: tech-lead · dispatches: the five below',
        artifact: 'branch + PR',
        fact: 'Never two agents at once. Chaos is a process failure, not a vibe.',
        file: 'principal-engineer.md',
      },
      {
        ini: 'DA',
        name: 'database-administrator',
        title: 'Database Administrator · phase 1',
        tier: 'sonnet',
        owns: 'Owns the relational schema — entities and migrations. Always runs first when new tables are needed; everything downstream builds on its work.',
        flow: 'phase 1 · hands to: platform-engineer',
        artifact: 'entities + migrations',
        fact: 'Schema before anything. Non-negotiable.',
        file: 'database-administrator.md',
      },
      {
        ini: 'PL',
        name: 'platform-engineer',
        title: 'Platform Engineer · phase 2',
        tier: 'sonnet',
        owns: 'Server-side infrastructure and serverless application code — handlers, stacks, config. Tech stack is whatever your repo says it is.',
        flow: 'phase 2 · hands to: sync / web / mobile',
        artifact: 'code + tests',
        fact: 'Will not touch your lockfile. Ever.',
        file: 'platform-engineer.md',
      },
      {
        ini: 'SE',
        name: 'sync-engineer',
        title: 'Sync Engineer · phase 3',
        tier: 'sonnet',
        owns: 'The offline-sync layer — sync rules, transaction builders, schema typegen, dead-letter queue. Runs only when the story needs offline writes.',
        flow: 'phase 3 · after: database + platform',
        artifact: 'sync rules + builders',
        fact: 'The specialist you forget exists until your app works on a plane.',
        file: 'sync-engineer.md',
      },
      {
        ini: 'WE',
        name: 'web-engineer',
        title: 'Web Engineer · phase 4',
        tier: 'sonnet',
        owns: 'The web frontend — pages, components, data hooks, client state. Scope is the web app workspace and nothing else.',
        flow: 'phase 4 · hands to: qa-engineer',
        artifact: 'code + tests',
        fact: 'Strict TypeScript. The word "any" is a code smell, not a type.',
        file: 'web-engineer.md',
      },
      {
        ini: 'ME',
        name: 'mobile-engineer',
        title: 'Mobile Engineer · phase 5',
        tier: 'sonnet',
        owns: 'Mobile screens, components, navigation, and offline-read hooks — the mobile app workspace end to end.',
        flow: 'phase 5 · hands to: qa-engineer',
        artifact: 'code + tests',
        fact: 'Tests on-device assumptions the web team never has to think about.',
        file: 'mobile-engineer.md',
      },
    ],
  },
  {
    eyebrow: '// quality',
    title: 'Quality',
    blurb:
      'Independent by construction: review is done by a different agent than the author, and nothing merges on vibes.',
    members: [
      {
        ini: 'QE',
        name: 'qa-engineer',
        title: 'QA Engineer · always-on',
        tier: 'opus',
        owns: 'Runs the review → fix → learn loop until the branch is clean: independent code review, quality gate with pasted output, acceptance-criteria verification, and learnings written back to team memory.',
        flow: 'after: all phases · verdict: clean | blocked',
        artifact: 'review + learnings → PR',
        fact: 'Never writes feature code. Finds the owner and makes them fix it.',
        file: 'qa-engineer.md',
      },
    ],
  },
  {
    eyebrow: '// opt-in specialist',
    title: 'On contract',
    blurb:
      'Joins only when a repo opts in at /sdlc:init — with a hard write-scope and a human-confirmation gate on every fix.',
    members: [
      {
        ini: 'AE',
        name: 'ai-enablement-engineer',
        title: 'AI Workflow Manager · opt-in',
        tier: 'sonnet',
        owns: "Owns the repo's AI-configuration surface — CLAUDE.md, .claude/**, plugins/**, skills/** — scanning for drift, gaps, and config-vs-memory conflicts, and applying fixes only as reviewable diffs after human confirmation.",
        flow: 'dependency-free · triggered by /sdlc:analyze',
        artifact: 'drift report + reviewable diffs',
        fact: 'The only agent allowed to edit the handbook — and only with your sign-off.',
        file: 'ai-enablement-engineer.md',
      },
    ],
  },
];

export const PHILOSOPHY: { title: string; body: string }[] = [
  {
    title: '// narrow charters',
    body: "Each role has its own prompt, tools, and owned paths. A narrow charter means fewer hallucinations — no agent speaks for another's domain.",
  },
  {
    title: '// artifacts, not vibes',
    body: 'Every handoff leaves a document you can read — PRD, stories, spec, plan, review learnings. The paper trail is the org chart.',
  },
  {
    title: '// one at a time',
    body: 'Domain agents run sequentially on a shared branch, never in parallel. Order is enforced: schema first, review last.',
  },
  {
    title: '// memory that compounds',
    body: 'Agents keep per-role memory archives, and QA writes review learnings back after every story. The team gets better at your repo over time.',
  },
];

export const HANDBOOK_STEPS: string[] = [
  'read project-context.md — the one file that makes generic agents yours',
  'load required skills — TDD, executing-plans, verification-before-completion',
  'read your project override — .claude/project/agents/<you>.md — and invoke every skill it lists',
  'read your memory archive — .claude/memories/agents/<you>.md',
  'touch only the paths you own — the workspace table is the law',
  'commit conventionally, leave your artifact, hand off clean',
];
