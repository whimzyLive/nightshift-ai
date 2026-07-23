'use client';

import { useEffect, useRef, useState } from 'react';

import { AnimatePresence, motion } from 'motion/react';

import {
  EASE_OUT,
  Eyebrow,
  prefersReducedMotion,
  Reveal,
  RevealGroup,
} from '@nightshift-ai/ui';

import { agents, ORG_LEVELS } from './team-data';
import type { AgentTone } from './team-data';

// Verbatim from the design handoff (nightshift Landing.dc.html L320-373).

// Matches the retired `--dur-twinkle` token (3.4s) / `ns-twinkle` keyframes.
const TWINKLE_ANIMATE = {
  opacity: [0.85, 1, 0.85],
  filter: ['brightness(1)', 'brightness(1.6)', 'brightness(1)'],
};
const TWINKLE_TRANSITION = {
  duration: 3.4,
  ease: 'easeInOut' as const,
  repeat: Infinity,
};

const HUMAN_KEY = 'you';
const HUMAN_META = {
  ini: 'YOU',
  owns: 'Refines by day, approves what is ready, reviews the PRs in the morning. Every gate hands control back here.',
  artifact: 'decisions',
};

// Initials + artifact per agent — verbatim from the design's CONST_DEFS
// (L665-676). Kept local rather than on `TeamAgent` (Task 3's exact type is
// name/owns/tone/standby only).
const AGENT_META: Record<string, { ini: string; artifact: string }> = {
  'product-manager': { ini: 'PM', artifact: 'PRD.md' },
  'solutions-architect': { ini: 'SA', artifact: 'spec.md' },
  'scrum-master': { ini: 'SM', artifact: 'stories' },
  'tech-lead': { ini: 'TL', artifact: 'plan.md' },
  'principal-engineer': { ini: 'PE', artifact: 'branch + dispatch' },
  'platform-engineer': { ini: 'PE', artifact: 'code + tests' },
  'web-engineer': { ini: 'WE', artifact: 'code + tests' },
  'mobile-engineer': { ini: 'ME', artifact: 'code + tests' },
  'database-administrator': { ini: 'DA', artifact: 'migrations' },
  'sync-engineer': { ini: 'SE', artifact: 'code + tests' },
  'qa-engineer': { ini: 'QE', artifact: 'review → PR' },
};

const TONE_COLOR: Record<AgentTone, string> = {
  accent: 'var(--accent)',
  info: 'var(--indigo-400)',
  cyan: 'var(--cyan-400)',
  green: 'var(--green-400)',
};

const AGENTS_BY_NAME = new Map(agents.map((a) => [a.name, a]));

// A3 — shared dot colour formula, reused for both the tree row's own dot and
// the charter panel's shared-element morph target so both ends of the morph
// agree on colour at every frame.
function dotColorFor(
  row: Pick<TreeRow, 'standby' | 'tone'>,
  isActive: boolean,
): string {
  if (row.standby) return 'var(--text-dim)';
  if (isActive) return 'var(--terra-400)';
  return row.tone ? TONE_COLOR[row.tone] : 'var(--moon-100)';
}

interface TreeRow {
  key: string;
  prefix: string;
  gate: boolean;
  star: boolean;
  label: string;
  cmds?: string;
  note?: string;
  tone?: AgentTone;
  standby?: boolean;
}

// Row/panel derivation mirrors design L1112-1182. Built once at module
// scope from static data — deterministic, so SSR and the client's first
// render always agree (no hydration mismatch).
function buildTreeRows(): TreeRow[] {
  const rows: TreeRow[] = [
    {
      key: HUMAN_KEY,
      prefix: '',
      gate: false,
      star: true,
      label: 'you (human)',
      note: '— every gate returns here',
    },
  ];

  const phases = ORG_LEVELS.slice(1); // L0 (human) already rendered above
  phases.forEach((level, idx) => {
    const last = idx === phases.length - 1;
    rows.push({
      key: level.num,
      prefix: last ? '└──' : '├──',
      gate: true,
      star: false,
      label: level.phase,
      cmds: level.commands.join(' · '),
    });

    const cont = last ? '    ' : '│   ';
    if (level.num === 'L5' && level.seqs) {
      const [lead, ...domains] = level.agentNames;
      const leadAgent = AGENTS_BY_NAME.get(lead);
      rows.push({
        key: lead,
        prefix: cont + '└──',
        gate: false,
        star: true,
        label: lead,
        note: '— orchestrates, one agent at a time',
        tone: leadAgent?.tone,
        standby: leadAgent?.standby,
      });
      domains.forEach((name, i) => {
        const domainLast = i === domains.length - 1;
        const domainAgent = AGENTS_BY_NAME.get(name);
        rows.push({
          key: name,
          prefix: cont + '    ' + (domainLast ? '└──' : '├──'),
          gate: false,
          star: true,
          label: name,
          note: `— ${level.seqs?.[name] ?? ''}`,
          tone: domainAgent?.tone,
          standby: domainAgent?.standby,
        });
      });
    } else {
      level.agentNames.forEach((name) => {
        const agent = AGENTS_BY_NAME.get(name);
        rows.push({
          key: name,
          prefix: cont + '└──',
          gate: false,
          star: true,
          label: name,
          note: `— ${AGENT_META[name]?.artifact ?? ''}`,
          tone: agent?.tone,
          standby: agent?.standby,
        });
      });
    }
  });

  return rows;
}

const TREE_ROWS = buildTreeRows();

const GITHUB_URL = 'https://github.com/whimzyLive/nightshift-ai';

interface SidePanel {
  eyebrow: string;
  ini?: string;
  name: string;
  standby: boolean;
  body: string;
  cmds?: string;
  artifact?: string;
  ref: string;
  refLabel: string;
}

const ORG_SUMMARY_PANEL: SidePanel = {
  eyebrow: '// the org, as a tree',
  name: '1 human · 11 agents',
  standby: false,
  body: '⊘ marks a hard gate — each phase ends there and control returns to you. Every ✶ is an agent with a tight charter. Hover any row to read its charter, contract, and source.',
  ref: GITHUB_URL,
  refLabel: 'whimzyLive/nightshift-ai',
};

function getSidePanel(active: string | null): SidePanel {
  if (active === null) return ORG_SUMMARY_PANEL;

  if (active === HUMAN_KEY) {
    return {
      eyebrow: '// agent charter',
      ini: HUMAN_META.ini,
      name: 'you',
      standby: false,
      body: HUMAN_META.owns,
      artifact: HUMAN_META.artifact,
      ref: GITHUB_URL,
      refLabel: 'whimzyLive/nightshift-ai',
    };
  }

  const agent = AGENTS_BY_NAME.get(active);
  if (agent) {
    const meta = AGENT_META[agent.name];
    return {
      eyebrow: '// agent charter',
      ini: meta?.ini,
      name: agent.name,
      standby: !!agent.standby,
      body: agent.owns,
      artifact: meta?.artifact,
      ref: `${GITHUB_URL}/blob/main/plugins/sdlc/agents/${agent.name}.md`,
      refLabel: `agents/${agent.name}.md`,
    };
  }

  const level = ORG_LEVELS.find((l) => l.num === active);
  if (level) {
    return {
      eyebrow: '// phase contract',
      name: `${level.num} · ${level.phase}`,
      standby: false,
      body: level.contract,
      cmds: level.commands.join('   '),
      ref: level.ref,
      refLabel: level.refLabel,
    };
  }

  return ORG_SUMMARY_PANEL;
}

// D2 — draggable agent constellation (hover/tab-gated easter egg).
const CONSTELLATION_WIDTH_PX = 220;
const CONSTELLATION_HEIGHT_PX = 140;
// Deterministic scatter (percent of the cluster box) — no Math.random at
// render time, matching the rest of the kit's SSR-safe pattern.
const CONSTELLATION_POSITIONS: { x: number; y: number }[] = agents.map(
  (_, i) => {
    const angle = (i / agents.length) * Math.PI * 2;
    const radiusX = 30 + (i % 3) * 12;
    const radiusY = 24 + (i % 4) * 8;
    return {
      x: 50 + Math.cos(angle) * radiusX,
      y: 50 + Math.sin(angle) * radiusY,
    };
  },
);

/**
 * A non-headline easter egg: a small `✦` focus target reveals a loose
 * cluster of the 11 agents as draggable star nodes (presentationally aligned
 * with `NightSky`'s star aesthetic), on hover OR keyboard tab-focus only —
 * never auto-presented, never promoted to a marketing element. Under
 * `prefers-reduced-motion`, the cluster still reveals but with `drag`
 * entirely omitted (no `drag`/`dragConstraints`/spring/inertia) — it
 * degrades to its final static state like every other sub-item, no
 * exception for the drag affordance.
 */
function AgentConstellation({ reducedMotion }: { reducedMotion: boolean }) {
  const [revealed, setRevealed] = useState(false);
  const boundsRef = useRef<HTMLDivElement>(null);

  return (
    <div
      className="relative mt-6 flex justify-center"
      onMouseEnter={() => setRevealed(true)}
      onMouseLeave={() => setRevealed(false)}
      onFocus={() => setRevealed(true)}
      onBlur={() => setRevealed(false)}
    >
      <button
        type="button"
        aria-label="Reveal the agent constellation"
        className="font-mono"
        style={{
          fontSize: 13,
          color: 'var(--text-dim)',
          padding: 4,
          background: 'transparent',
          border: 'none',
          cursor: 'pointer',
        }}
      >
        ✦
      </button>
      {revealed && (
        <div
          ref={boundsRef}
          aria-hidden="true"
          data-testid="agent-constellation"
          className="pointer-events-none absolute"
          style={{
            top: '100%',
            left: '50%',
            transform: 'translateX(-50%)',
            width: CONSTELLATION_WIDTH_PX,
            height: CONSTELLATION_HEIGHT_PX,
          }}
        >
          {agents.map((agent, i) => {
            const pos = CONSTELLATION_POSITIONS[i];
            const dragProps = reducedMotion
              ? {}
              : {
                  drag: true as const,
                  dragConstraints: boundsRef,
                  dragElastic: 0.2,
                };
            return (
              <motion.span
                key={agent.name}
                data-testid="constellation-star"
                className="pointer-events-auto absolute rounded-full"
                {...dragProps}
                style={{
                  left: `${pos.x}%`,
                  top: `${pos.y}%`,
                  width: 8,
                  height: 8,
                  background: TONE_COLOR[agent.tone],
                  cursor: reducedMotion ? 'default' : 'grab',
                }}
              />
            );
          })}
        </div>
      )}
    </div>
  );
}

/**
 * The team preview: two-column terminal-tree + sticky charter panel. Local
 * `active` hover state only (no global store) — dims non-active rows,
 * updates the panel, and resets on `onMouseLeave` of the tree container
 * (`#ns-org`, matching the design's own id). Server-rendered default state
 * (org summary, full opacity) is fully legible without hover (AC5).
 */
export function TeamPreview() {
  const [active, setActive] = useState<string | null>(null);
  const [reducedMotion, setReducedMotion] = useState(false);
  const panel = getSidePanel(active);
  // A3 — the tree row backing the current panel, if any (only star rows —
  // human + agents — have a matching dot/name to morph into the panel).
  const activeRow = active ? TREE_ROWS.find((r) => r.key === active) : null;

  // Direct `matchMedia` check (not Motion's `useReducedMotion`) — checked
  // once post-mount so the deterministic server/first-hydration frame
  // matches, then gates the twinkle loop off for reduced-motion users.
  useEffect(() => {
    setReducedMotion(prefersReducedMotion());
  }, []);

  return (
    <section
      id="agents"
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen border-t ns-cv"
      style={{
        padding: '80px 28px',
        background: 'var(--bg-void)',
        borderColor: 'var(--border-default)',
      }}
    >
      <div className="mx-auto" style={{ maxWidth: 1200 }}>
        <RevealGroup className="mb-10 text-center">
          <Reveal>
            <Eyebrow>04 · the team</Eyebrow>
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
            A team, not a megaprompt
          </Reveal>
          <Reveal
            as="p"
            className="mx-auto"
            style={{
              fontSize: 18,
              lineHeight: 1.6,
              color: 'var(--text-muted)',
              maxWidth: 680,
            }}
          >
            &quot;Do everything&quot; agents hallucinate across roles and leave
            no trail. nightshift splits the work across 11 agents, each with a
            tight charter, its own prompt and tools, and a clean handoff to the
            next. Narrow charters mean fewer hallucinations and an auditable
            artifact at every stage.
          </Reveal>
        </RevealGroup>

        <div
          id="ns-org"
          className="mx-auto mt-9 grid grid-cols-1 items-start gap-[26px] lg:grid-cols-[1fr_350px]"
          style={{ maxWidth: 1120 }}
          onMouseLeave={() => setActive(null)}
        >
          <div
            data-lift
            className="overflow-x-auto border p-6"
            style={{
              background: 'var(--surface-terminal)',
              borderColor: 'var(--border-default)',
            }}
          >
            <div
              className="mb-4 font-mono"
              style={{ fontSize: 13, color: 'var(--text-dim)' }}
            >
              <span style={{ color: 'var(--green-400)' }}>$</span> nightshift
              --team --tree
            </div>
            {TREE_ROWS.map((row) => {
              const isActive = active === row.key;
              const dotColor = dotColorFor(row, isActive);
              return (
                <div
                  key={row.key}
                  onMouseEnter={() => setActive(row.key)}
                  className="flex items-center gap-[9px] font-mono whitespace-nowrap"
                  style={{
                    fontSize: 14.5,
                    lineHeight: 2.15,
                    cursor: 'pointer',
                    opacity: active === null || isActive ? 1 : 0.45,
                    transition: 'opacity .2s',
                  }}
                >
                  <span
                    style={{ color: 'rgba(217,119,87,.45)', whiteSpace: 'pre' }}
                  >
                    {row.prefix}
                  </span>
                  {row.gate && (
                    <span
                      title="hard gate — control returns to you"
                      style={{ color: 'var(--accent)', flex: 'none' }}
                    >
                      ⊘
                    </span>
                  )}
                  {row.star && (
                    <motion.span
                      aria-hidden="true"
                      data-testid="team-dot"
                      data-twinkle={reducedMotion ? 'off' : 'on'}
                      layoutId={
                        reducedMotion ? undefined : `agent-dot-${row.key}`
                      }
                      animate={reducedMotion ? undefined : TWINKLE_ANIMATE}
                      transition={
                        reducedMotion ? undefined : TWINKLE_TRANSITION
                      }
                      style={{
                        width: row.key === HUMAN_KEY ? 15 : 11,
                        height: row.key === HUMAN_KEY ? 15 : 11,
                        borderRadius: '50%',
                        background: dotColor,
                        flex: 'none',
                      }}
                    />
                  )}
                  <motion.span
                    layoutId={
                      row.star && !reducedMotion
                        ? `agent-name-${row.key}`
                        : undefined
                    }
                    style={{
                      color: isActive
                        ? 'var(--terra-400)'
                        : row.standby
                          ? 'var(--text-dim)'
                          : 'var(--moon-100)',
                    }}
                  >
                    {row.label}
                  </motion.span>
                  {row.cmds && (
                    <span style={{ color: 'var(--terra-400)', opacity: 0.85 }}>
                      {row.cmds}
                    </span>
                  )}
                  {row.note && (
                    <span style={{ color: 'var(--text-dim)' }}>{row.note}</span>
                  )}
                  {row.standby && (
                    <span
                      style={{
                        fontSize: 10,
                        letterSpacing: '.12em',
                        color: 'var(--text-dim)',
                      }}
                    >
                      STANDBY
                    </span>
                  )}
                </div>
              );
            })}
          </div>

          <div
            data-lift
            className="flex flex-col gap-3 border p-6"
            style={{
              position: 'sticky',
              top: 110,
              background: 'rgba(13,13,24,.85)',
              borderColor: 'var(--border-default)',
              minHeight: 300,
            }}
          >
            <AnimatePresence mode="wait" initial={false}>
              <motion.div
                key={active ?? 'summary'}
                className="flex flex-col gap-3"
                initial={reducedMotion ? false : { opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={reducedMotion ? undefined : { opacity: 0 }}
                transition={{
                  duration: reducedMotion ? 0 : 0.2,
                  ease: EASE_OUT,
                }}
              >
                <div
                  className="font-mono uppercase"
                  style={{
                    fontSize: 12,
                    letterSpacing: '.16em',
                    color: 'var(--accent)',
                  }}
                >
                  {panel.eyebrow}
                </div>
                <div className="flex flex-wrap items-center gap-[10px]">
                  {activeRow?.star && (
                    <motion.span
                      aria-hidden="true"
                      data-testid="panel-dot"
                      layoutId={
                        reducedMotion ? undefined : `agent-dot-${active}`
                      }
                      style={{
                        width: active === HUMAN_KEY ? 15 : 11,
                        height: active === HUMAN_KEY ? 15 : 11,
                        borderRadius: '50%',
                        background: dotColorFor(activeRow, true),
                        flex: 'none',
                      }}
                    />
                  )}
                  {panel.ini && (
                    <span
                      className="font-mono"
                      style={{
                        fontSize: 13,
                        color: 'var(--accent)',
                        border: '1px solid var(--border-accent)',
                        padding: '2px 8px',
                      }}
                    >
                      {panel.ini}
                    </span>
                  )}
                  <motion.span
                    layoutId={
                      activeRow?.star && !reducedMotion
                        ? `agent-name-${active}`
                        : undefined
                    }
                    className="font-mono"
                    style={{ fontSize: 16, color: 'var(--moon-100)' }}
                  >
                    {panel.name}
                  </motion.span>
                  {panel.standby && (
                    <span
                      className="font-mono"
                      style={{
                        fontSize: 10,
                        letterSpacing: '.12em',
                        color: 'var(--text-dim)',
                      }}
                    >
                      STANDBY
                    </span>
                  )}
                </div>
                <p
                  style={{
                    fontSize: 15,
                    lineHeight: 1.6,
                    color: 'var(--text-muted)',
                    margin: 0,
                  }}
                >
                  {panel.body}
                </p>
                {panel.cmds && (
                  <p
                    className="font-mono"
                    style={{
                      fontSize: 13,
                      color: 'var(--terra-400)',
                      margin: 0,
                    }}
                  >
                    {panel.cmds}
                  </p>
                )}
                {panel.artifact && (
                  <p
                    className="font-mono"
                    style={{
                      fontSize: 13,
                      color: 'var(--text-dim)',
                      margin: 0,
                    }}
                  >
                    artifact →{' '}
                    <span style={{ color: 'var(--cyan-400)' }}>
                      {panel.artifact}
                    </span>
                  </p>
                )}
                <a
                  href={panel.ref}
                  target="_blank"
                  rel="noopener"
                  className="font-mono"
                  style={{
                    fontSize: 12.5,
                    color: 'var(--link)',
                    marginTop: 'auto',
                  }}
                >
                  {panel.refLabel} ↗
                </a>
              </motion.div>
            </AnimatePresence>
          </div>
        </div>

        <p
          className="mt-4 text-center font-mono"
          style={{ fontSize: 13, color: 'var(--text-dim)' }}
        >
          ⊘ every phase ends at a hard gate — control returns to you before the
          next one runs · hover a row for its charter
        </p>
        <p className="mt-[22px] text-center">
          <a
            href="/team"
            className="font-mono"
            style={{ fontSize: 15, color: 'var(--link)' }}
          >
            Meet the whole team — charters, handoffs, org chart →
          </a>
        </p>

        <AgentConstellation reducedMotion={reducedMotion} />
      </div>
    </section>
  );
}
