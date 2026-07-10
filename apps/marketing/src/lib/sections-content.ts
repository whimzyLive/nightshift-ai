// Hardcoded nightshift product copy for the homepage sections below the
// hero (NA-21). CMS-sourcing this content is a follow-on story — only the
// hero is Payload-backed for now. Kept dependency-free (no Payload/Next
// imports) so it can be imported from client components without dragging in
// server-only code, mirroring the `hero-defaults.ts` pattern.

export interface PipelineIdea {
  n: string;
  title: string;
  body: string;
}

export const PIPELINE_IDEAS: PipelineIdea[] = [
  {
    n: '01',
    title: 'A team, not a megaprompt',
    body: 'Each role is a separate agent with its own system prompt, tools, and memory. Narrow charters mean fewer hallucinations and cleaner handoffs.',
  },
  {
    n: '02',
    title: 'Generic agents, per-repo config',
    body: 'The agents carry zero project specifics. Stack, owned paths, issue-tracker key, base branch, quality gates — all live in one project-context.md the plugin loads every session.',
  },
  {
    n: '03',
    title: 'The lifecycle is the product',
    body: 'Spec before plan, plan before code, review before merge. Tests are the gate. Reviews are done by a different agent than the one who wrote the code.',
  },
];

export interface PipelineStage {
  command: string;
  label: string;
  agent: string;
  status: 'idle' | 'active' | 'done';
}

export const PIPELINE_STAGES: PipelineStage[] = [
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
    status: 'done',
  },
  {
    command: '/review',
    label: 'Quality gate',
    agent: 'qa-engineer',
    status: 'done',
  },
  { command: 'PR', label: 'Ship it', agent: '/auto', status: 'active' },
];

export interface TerminalLine {
  prompt?: string;
  agent?: string;
  text: string;
  tone?: 'default' | 'muted' | 'accent' | 'success';
}

// Sequential /auto run — spec, plan, impl, review each land with a ✓ mark,
// then the prompt resets so the loop can replay (AC2).
export const TERMINAL_LINES: TerminalLine[] = [
  { prompt: '$', text: '/auto NA-21' },
  {
    agent: 'spec',
    text: 'solutions-architect  ✓ technical spec written',
    tone: 'success',
  },
  {
    agent: 'plan',
    text: 'tech-lead            ✓ ordered, verifiable plan',
    tone: 'success',
  },
  {
    agent: 'impl',
    text: 'principal-engineer   ✓ web-engineer dispatched',
    tone: 'success',
  },
  {
    agent: 'review',
    text: 'qa-engineer          ✓ quality gate passed',
    tone: 'success',
  },
  { text: '→ opened PR · commented on NA-21', tone: 'accent' },
  { prompt: '$', text: '▌' },
];

export interface Agent {
  name: string;
  owns: string;
  tone: 'accent' | 'info' | 'cyan' | 'green';
  standby?: boolean;
}

export const TEAM: Agent[] = [
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

export interface Stat {
  id: string;
  value: number;
  suffix?: string;
  label: string;
}

export const STATS: Stat[] = [
  { id: 'agents', value: 11, label: 'specialized agents' },
  { id: 'commands', value: 10, label: 'slash commands' },
  { id: 'install', value: 60, suffix: 's', label: 'install' },
];

export const INSTALL_COMMANDS: string[] = [
  '/plugin marketplace add whimzyLive/nightshift-ai',
  '/plugin install sdlc@nightshift',
];
