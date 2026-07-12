// Verbatim from the design handoff (nightshift Landing.dc.html L679-723, L1361-1373).

export type AgentTone = 'accent' | 'info' | 'cyan' | 'green';

export interface TeamAgent {
  /** Agent file name / tree label, e.g. 'solutions-architect'. */
  name: string;
  /** Charter shown as the side-panel body. */
  owns: string;
  /** Dot colour tone. */
  tone: AgentTone;
  /** True for roles not exercised on this repo (renders a STANDBY tag). */
  standby?: boolean;
}

export interface OrgPhase {
  /** Level id, e.g. 'L3'. */
  num: string;
  /** Phase label shown on the gate row. */
  phase: string;
  /** Slash-commands for this phase, e.g. ['/spec']. */
  commands: string[];
  /** Phase contract shown in the side panel when a gate row is hovered. */
  contract: string;
  /** Repo reference URL for the phase. */
  ref: string;
  /** Human-readable ref label. */
  refLabel: string;
  /** Agent names that belong to this phase. */
  agentNames: string[];
  /**
   * L5-only: per-domain-agent sequence label shown in its tree row note
   * (design L716, e.g. 'phase 1'). Optional — every other phase has a
   * single implicit agent and needs no sequencing note.
   */
  seqs?: Record<string, string>;
}

export const agents: TeamAgent[] = [
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
  {
    name: 'web-engineer',
    owns: 'Web UI',
    tone: 'cyan',
  },
  {
    name: 'mobile-engineer',
    owns: 'Mobile apps',
    tone: 'cyan',
    standby: true,
  },
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

export const ORG_LEVELS: OrgPhase[] = [
  {
    num: 'L0',
    phase: 'you (human)',
    commands: ['review · approve'],
    contract:
      'The only non-agent in the org. You refine by day, approve what is ready, and review the PRs in the morning — nothing advances past a gate without your sign-off.',
    ref: 'https://github.com/whimzyLive/nightshift-ai',
    refLabel: 'whimzyLive/nightshift-ai',
    agentNames: ['you'],
  },
  {
    num: 'L1',
    phase: 'refine feature',
    commands: ['/refine-feature', '/prd'],
    contract:
      'Raw idea → Jira Epic → PRD with 5–10 binary acceptance criteria, committed to docs/features/ on its own branch.',
    ref: 'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/agents/product-manager.md',
    refLabel: 'agents/product-manager.md',
    agentNames: ['product-manager'],
  },
  {
    num: 'L2',
    phase: 'refine story',
    commands: ['/refine-issue', '/stories'],
    contract:
      'Epic → story map → well-formed, dependency-ordered stories in Jira; rough stakeholder tickets triaged in place.',
    ref: 'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/agents/scrum-master.md',
    refLabel: 'agents/scrum-master.md',
    agentNames: ['scrum-master'],
  },
  {
    num: 'L3',
    phase: 'spec',
    commands: ['/spec'],
    contract:
      'Story → docs/superpowers/specs/<KEY>.md — data model, API surface, per-workspace implementation guide — raised as its own PR.',
    ref: 'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/agents/solutions-architect.md',
    refLabel: 'agents/solutions-architect.md',
    agentNames: ['solutions-architect'],
  },
  {
    num: 'L4',
    phase: 'plan',
    commands: ['/plan'],
    contract:
      'Spec → docs/superpowers/plans/<KEY>.md — ordered, agent-tagged phases, each ending in a verification step.',
    ref: 'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/agents/tech-lead.md',
    refLabel: 'agents/tech-lead.md',
    agentNames: ['tech-lead'],
  },
  {
    num: 'L5',
    phase: 'implement',
    commands: ['/impl'],
    contract:
      'Plan → code + tests on an impl branch. principal-engineer dispatches one domain agent at a time, in dependency order — schema first, then backend, sync, web, mobile.',
    ref: 'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/agents/principal-engineer.md',
    refLabel: 'agents/principal-engineer.md',
    agentNames: [
      'principal-engineer',
      'database-administrator',
      'platform-engineer',
      'sync-engineer',
      'web-engineer',
      'mobile-engineer',
    ],
    seqs: {
      'principal-engineer': 'orchestrates',
      'database-administrator': 'phase 1',
      'platform-engineer': 'phase 2',
      'sync-engineer': 'phase 3',
      'web-engineer': 'phase 4',
      'mobile-engineer': 'phase 5',
    },
  },
  {
    num: 'L6',
    phase: 'qa / review',
    commands: ['/review', '/review-fix'],
    contract:
      'Independent review by a different agent than the author → quality gate → AC verification → reviewed PR, commented back to the ticket.',
    ref: 'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/agents/qa-engineer.md',
    refLabel: 'agents/qa-engineer.md',
    agentNames: ['qa-engineer'],
  },
];
