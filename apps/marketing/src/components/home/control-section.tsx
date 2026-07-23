'use client';

import { useEffect, useReducer, useRef, useState } from 'react';
import type { ChangeEvent } from 'react';

import { motion } from 'motion/react';

import {
  CtaButton,
  Eyebrow,
  GateCheck,
  prefersReducedMotion,
  Reveal,
  RevealGroup,
} from '@nightshift-ai/ui';

// Verbatim from the design handoff (nightshift Landing.dc.html L404-532,
// state/logic L620-663 + L1083-1340, `class Component`/`renderVals`).

type GateKey = 'refine' | 'spec' | 'plan' | 'implement' | 'review';
type TicketType = 'story' | 'bug';
type ApprovalMode = 'assisted' | 'auto' | 'full-auto';
type GateStatus = 'working' | 'awaiting';

interface ControlState {
  ticketType: TicketType;
  storyPts: number;
  thresh: number;
  approvalMode: ApprovalMode;
  gI: number;
  gS: GateStatus;
  gDone: boolean;
  raceStep: number;
}

const INITIAL_STATE: ControlState = {
  ticketType: 'story',
  storyPts: 8,
  thresh: 3,
  approvalMode: 'assisted',
  gI: 0,
  gS: 'working',
  gDone: false,
  raceStep: 0,
};

const WORKING_MS = 1700;
const WORKING_MS_REDUCED = 400;
const AUTO_ADVANCE_MS = 700;
const FULL_AUTO_LOOP_MS = 3200;

// Matches the retired `--ease-out` token (cubic-bezier(.22,1,.36,1)).
const EASE_OUT: [number, number, number, number] = [0.22, 1, 0.36, 1];
// Matches the retired `ns-twinkle` keyframes / `--dur-twinkle` token.
const TWINKLE_ANIMATE = {
  opacity: [0.85, 1, 0.85],
  filter: ['brightness(1)', 'brightness(1.6)', 'brightness(1)'],
};
// Matches the retired `ns-gatepulse` keyframes (1.3s, scale + brightness).
const GATE_PULSE_ANIMATE = {
  scale: [1, 1.14, 1],
  filter: ['brightness(1)', 'brightness(1.45)', 'brightness(1)'],
};

const APPROVAL_MODES: ApprovalMode[] = ['assisted', 'auto', 'full-auto'];

const CTRL_MAP: Record<
  GateKey,
  {
    label: string;
    cmd: string;
    agent: string;
    working: string;
    ready: string;
    approved: string;
  }
> = {
  refine: {
    label: 'refine',
    cmd: '/refine-issue',
    agent: 'scrum-master',
    working: 'refining PROJ-142 — story shape, binary acceptance criteria …',
    ready: 'story well-formed',
    approved: '⊘ story refined',
  },
  spec: {
    label: 'spec',
    cmd: '/spec',
    agent: 'solutions-architect',
    working: 'writing docs/superpowers/specs/PROJ-142.md …',
    ready: 'spec ready',
    approved: '⊘ specs/PROJ-142.md',
  },
  plan: {
    label: 'plan',
    cmd: '/plan',
    agent: 'tech-lead',
    working: 'writing docs/superpowers/plans/PROJ-142.md …',
    ready: 'plan ready',
    approved: '⊘ plans/PROJ-142.md',
  },
  implement: {
    label: 'implement',
    cmd: '/impl',
    agent: 'principal-engineer',
    working: 'dispatching domain agents in dependency order …',
    ready: 'code + tests green',
    approved: '⊘ code + tests green',
  },
  review: {
    label: 'review',
    cmd: '/review',
    agent: 'qa-engineer',
    working: 'independent review — quality gate, AC verification …',
    ready: 'review clean',
    approved: '⊘ independent review',
  },
};

// ---- pure derivations (recomputed every render — never stored, AC4) ----

function computeRoute(
  ticketType: TicketType,
  storyPts: number,
  thresh: number,
): GateKey[] {
  if (ticketType === 'bug') return ['implement', 'review'];
  return storyPts <= thresh
    ? ['refine', 'implement', 'review']
    : ['refine', 'spec', 'plan', 'implement', 'review'];
}

function isGateAuto(
  route: GateKey[],
  i: number,
  approvalMode: ApprovalMode,
): boolean {
  if (approvalMode === 'full-auto') return true;
  if (approvalMode !== 'auto') return false;
  const k = route[i];
  return k !== 'spec' && k !== 'review';
}

function computeRouteName(isBug: boolean, lightStory: boolean): string {
  if (isBug) return 'defect route';
  return lightStory ? 'lightweight route' : 'full ceremony';
}

interface TicketChip {
  label: string;
  color: string;
  border: string;
  bg: string;
}

interface TriageLane {
  title: string;
  note: string;
  path: string;
  tickets: TicketChip[];
  border: string;
  bg: string;
  titleColor: string;
}

function buildTriageLanes(state: ControlState): TriageLane[] {
  const { ticketType, storyPts: pts, thresh: thr } = state;
  const isBug = ticketType === 'bug';
  const lightStory = !isBug && pts <= thr;
  const ticketChip: TicketChip = isBug
    ? {
        label: 'PROJ-142 · bug',
        color: 'var(--red-400)',
        border: 'rgba(224,101,111,.45)',
        bg: 'rgba(224,101,111,.1)',
      }
    : {
        label: `PROJ-142 · ${pts} pts`,
        color: 'var(--terra-400)',
        border: 'var(--border-accent)',
        bg: 'rgba(217,119,87,.12)',
      };
  const mkLane = (
    title: string,
    note: string,
    path: string,
    tickets: TicketChip[],
  ): TriageLane => ({
    title,
    note,
    path,
    tickets,
    border: tickets.length ? 'var(--border-accent)' : 'var(--border-soft)',
    bg: tickets.length ? 'rgba(217,119,87,.05)' : 'transparent',
    titleColor: tickets.length ? 'var(--moon-100)' : 'var(--text-dim)',
  });
  return [
    mkLane(
      'full ceremony',
      'story > threshold',
      '/spec → /plan → /impl → /review',
      !isBug && !lightStory ? [ticketChip] : [],
    ),
    mkLane(
      'lightweight',
      'story ≤ threshold — skips spec + plan',
      '/impl → /review',
      lightStory ? [ticketChip] : [],
    ),
    mkLane(
      'defect',
      'bugs never spec or plan',
      '/impl → /review',
      isBug ? [ticketChip] : [],
    ),
  ];
}

function buildTriageMsg(state: ControlState): string {
  const { ticketType, storyPts: pts, thresh: thr } = state;
  if (ticketType === 'bug') {
    return 'PROJ-142 issuetype=bug → defects skip spec/plan → /impl';
  }
  if (pts <= thr) {
    return `PROJ-142 story · ${pts} pts ≤ ${thr} → lightweight — tasks derived inline, straight to /impl`;
  }
  return `PROJ-142 story · ${pts} pts > ${thr} → full ceremony — spec before plan, plan before code`;
}

interface CtrlGate {
  key: GateKey;
  label: string;
  conn: boolean;
  connBg: string;
  glyph: string;
  done: boolean;
  border: string;
  bg: string;
  color: string;
  glow: string;
  awaiting: boolean;
  labelColor: string;
}

function buildCtrlGates(
  route: GateKey[],
  gI: number,
  gS: GateStatus,
  gDone: boolean,
): CtrlGate[] {
  return route.map((k, i) => {
    const p = CTRL_MAP[k];
    const done = gDone || i < gI;
    const current = !gDone && i === gI;
    const awaiting = current && gS === 'awaiting';
    return {
      key: k,
      label: p.label,
      conn: i > 0,
      connBg:
        done || (current && i > 0)
          ? 'rgba(217,119,87,.55)'
          : 'var(--border-strong)',
      glyph: done ? '✓' : '⊘',
      done,
      border:
        done || current ? 'var(--border-accent)' : 'var(--border-default)',
      bg: done
        ? 'rgba(217,119,87,.28)'
        : current
          ? 'rgba(217,119,87,.1)'
          : 'transparent',
      color: done || current ? 'var(--terra-400)' : 'var(--text-dim)',
      glow: awaiting
        ? '0 0 18px rgba(217,119,87,.6)'
        : done
          ? '0 0 8px rgba(217,119,87,.25)'
          : 'none',
      awaiting,
      labelColor: done || current ? 'var(--moon-100)' : 'var(--text-dim)',
    };
  });
}

type RaceLine = { blob: true } | { t: string; color: string };

function buildRaceLeft(raceStep: number): RaceLine[] {
  const items: RaceLine[] = [
    { t: '> build PROJ-142', color: 'var(--moon-200)' },
  ];
  if (raceStep >= 1 && raceStep < 7) {
    items.push({
      t: 'thinking … (no spec, no plan, no questions asked)',
      color: 'var(--text-dim)',
    });
  }
  if (raceStep >= 3 && raceStep < 7) {
    items.push({
      t: 'still building … you have no idea what',
      color: 'var(--text-dim)',
    });
  }
  if (raceStep >= 7) items.push({ blob: true });
  if (raceStep >= 8) {
    items.push({
      t: '4,213 lines changed · one commit · no paper trail',
      color: 'var(--amber-400)',
    });
  }
  if (raceStep >= 9) {
    items.push({
      t: '✗ reinvented your auth — ignored the existing session middleware',
      color: 'var(--red-400)',
    });
  }
  if (raceStep >= 10) {
    items.push({
      t: '✗ acceptance criteria met: 2 of 7',
      color: 'var(--red-400)',
    });
  }
  if (raceStep >= 11) {
    items.push({
      t: '❓ built the wrong thing. read all 4,213 lines to find out where.',
      color: 'var(--red-400)',
    });
  }
  return items;
}

function buildRaceRight(
  state: ControlState,
  route: GateKey[],
  routeName: string,
): { t: string; color: string }[] {
  const {
    ticketType,
    storyPts: pts,
    thresh: thr,
    approvalMode: mode,
    gI,
    gS,
    gDone,
  } = state;
  const isBug = ticketType === 'bug';
  const lightStory = !isBug && pts <= thr;
  const items: { t: string; color: string }[] = [];

  if (mode === 'assisted') {
    items.push({
      t: `# route: ${routeName} — one verb per phase, per project-context.md`,
      color: 'var(--cyan-400)',
    });
  } else {
    items.push({ t: '> /auto PROJ-142', color: 'var(--moon-200)' });
    items.push({
      t: isBug
        ? '⊘ triage: issuetype=bug → defects skip spec/plan → /impl'
        : lightStory
          ? `⊘ triage: ${pts} pts ≤ threshold ${thr} → lightweight — spec + plan skipped`
          : `⊘ triage: ${pts} pts > threshold ${thr} → full ceremony`,
      color: 'var(--cyan-400)',
    });
  }

  route.forEach((k, i) => {
    const started = gDone || i <= gI;
    if (mode === 'assisted' && started) {
      items.push({
        t: `> ${CTRL_MAP[k].cmd} PROJ-142`,
        color: 'var(--moon-100)',
      });
    }
    if (gDone || i < gI) {
      items.push({
        t:
          CTRL_MAP[k].approved +
          (isGateAuto(route, i, mode)
            ? ' — auto-approved by config'
            : ' — you approved'),
        color: 'var(--moon-200)',
      });
    }
  });

  if (!gDone) {
    const cp = CTRL_MAP[route[Math.min(gI, route.length - 1)]];
    const curAuto = isGateAuto(route, gI, mode);
    if (gS === 'working') {
      items.push({
        t: `${cp.agent} → ${cp.working}`,
        color: 'var(--moon-300)',
      });
    } else {
      items.push({
        t:
          `⊘ gate: ${cp.ready}` +
          (curAuto
            ? ` — auto-approving (approval_mode: ${mode})`
            : ' — awaiting your approval'),
        color: 'var(--terra-400)',
      });
    }
  } else {
    items.push({
      t:
        `→ PR #318 · ${routeName}` +
        (mode === 'assisted'
          ? ' · every phase ran on your approval'
          : mode === 'auto'
            ? ' · auto-ran — you approved spec + review'
            : ' · gates auto-approved by your config'),
      color: 'var(--green-400)',
    });
  }

  return items;
}

function buildApprovalModeHint(mode: ApprovalMode): string {
  if (mode === 'assisted')
    return 'assisted — every gate waits for your approval';
  if (mode === 'auto') {
    return 'auto — you approve spec and review; the rest flows through';
  }
  return 'full-auto — every gate auto-approves; runs on a loop';
}

// ---- reducer (pure — every side effect lives in the effects below) ----

type Action =
  | { type: 'SET_STORY_PTS'; payload: number }
  | { type: 'INC_THRESHOLD' }
  | { type: 'DEC_THRESHOLD' }
  | { type: 'SET_TICKET_TYPE'; payload: TicketType }
  | { type: 'CYCLE_MODE' }
  | { type: 'RESTART_GATE' }
  | { type: 'SET_GATE_AWAITING' }
  | { type: 'ADVANCE_GATE' }
  | { type: 'RACE_STEP_TICK' }
  | { type: 'SET_RACE_STEP'; payload: number };

function reducer(state: ControlState, action: Action): ControlState {
  switch (action.type) {
    case 'SET_STORY_PTS':
      return { ...state, storyPts: action.payload };
    case 'INC_THRESHOLD':
      return { ...state, thresh: Math.min(8, state.thresh + 1) };
    case 'DEC_THRESHOLD':
      return { ...state, thresh: Math.max(1, state.thresh - 1) };
    case 'SET_TICKET_TYPE':
      return { ...state, ticketType: action.payload };
    case 'CYCLE_MODE': {
      const next =
        APPROVAL_MODES[
          (APPROVAL_MODES.indexOf(state.approvalMode) + 1) %
            APPROVAL_MODES.length
        ];
      return { ...state, approvalMode: next };
    }
    case 'RESTART_GATE':
      return { ...state, gI: 0, gS: 'working', gDone: false };
    case 'SET_GATE_AWAITING':
      return { ...state, gS: 'awaiting' };
    case 'ADVANCE_GATE': {
      const route = computeRoute(
        state.ticketType,
        state.storyPts,
        state.thresh,
      );
      if (state.gI >= route.length - 1) return { ...state, gDone: true };
      return { ...state, gI: state.gI + 1, gS: 'working' };
    }
    case 'RACE_STEP_TICK':
      return { ...state, raceStep: Math.min(state.raceStep + 1, 12) };
    case 'SET_RACE_STEP':
      return { ...state, raceStep: action.payload };
    default:
      return state;
  }
}

/**
 * Home section 8 — "You decide how it gets built". Single client island
 * owning the whole state machine; the triage router, gate strip, and
 * right-hand terminal all derive their view from this one state so they
 * can never desync (AC4). All timer handles are cleared on unmount and
 * before every restart (config change or explicit reset).
 */
export function ControlSection() {
  const [state, dispatch] = useReducer(reducer, INITIAL_STATE);
  const raceIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const [reducedMotion, setReducedMotion] = useState(false);

  // Direct `matchMedia` check (not Motion's `useReducedMotion`) — checked
  // once post-mount so the deterministic server/first-hydration frame
  // matches, then gates every Motion entrance/loop in this section off for
  // reduced-motion users.
  useEffect(() => {
    setReducedMotion(prefersReducedMotion());
  }, []);

  const {
    ticketType,
    storyPts,
    thresh,
    approvalMode,
    gI,
    gS,
    gDone,
    raceStep,
  } = state;

  // Restart the gate walk on mount AND on every config change (AC4).
  useEffect(() => {
    dispatch({ type: 'RESTART_GATE' });
  }, [ticketType, storyPts, thresh, approvalMode]);

  // Per-gate "working" timer — flips to 'awaiting' after ~1700ms (~400ms
  // under reduced motion).
  useEffect(() => {
    if (gS !== 'working') return;
    const ms = prefersReducedMotion() ? WORKING_MS_REDUCED : WORKING_MS;
    const id = setTimeout(() => dispatch({ type: 'SET_GATE_AWAITING' }), ms);
    return () => clearTimeout(id);
  }, [gI, gS]);

  // Auto-approval — once awaiting, schedule the advance if this gate
  // auto-approves under the current mode.
  useEffect(() => {
    if (gS !== 'awaiting' || gDone) return;
    const route = computeRoute(ticketType, storyPts, thresh);
    if (!isGateAuto(route, gI, approvalMode)) return;
    const id = setTimeout(
      () => dispatch({ type: 'ADVANCE_GATE' }),
      AUTO_ADVANCE_MS,
    );
    return () => clearTimeout(id);
  }, [gI, gS, gDone, ticketType, storyPts, thresh, approvalMode]);

  // full-auto loops the whole route again once done.
  useEffect(() => {
    if (!gDone || approvalMode !== 'full-auto') return;
    const id = setTimeout(
      () => dispatch({ type: 'RESTART_GATE' }),
      FULL_AUTO_LOOP_MS,
    );
    return () => clearTimeout(id);
  }, [gDone, approvalMode]);

  // One-shot `raceStep` terminal script — independent of the gate machine,
  // never loops. Under reduced motion, jump straight to the end state.
  useEffect(() => {
    if (prefersReducedMotion()) {
      dispatch({ type: 'SET_RACE_STEP', payload: 12 });
      return;
    }
    const id = setInterval(() => dispatch({ type: 'RACE_STEP_TICK' }), 1000);
    raceIntervalRef.current = id;
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    if (raceStep >= 12 && raceIntervalRef.current) {
      clearInterval(raceIntervalRef.current);
      raceIntervalRef.current = null;
    }
  }, [raceStep]);

  const isBug = ticketType === 'bug';
  const isStory = !isBug;
  const lightStory = !isBug && storyPts <= thresh;
  const route = computeRoute(ticketType, storyPts, thresh);
  const routeName = computeRouteName(isBug, lightStory);
  const curAuto = isGateAuto(route, gI, approvalMode);
  const ctrlAwaiting = !gDone && gS === 'awaiting' && !curAuto;
  const ctrlWorking =
    !gDone && (gS === 'working' || (gS === 'awaiting' && curAuto));
  const ctrlDone = gDone && approvalMode !== 'full-auto';

  const triageLanes = buildTriageLanes(state);
  const triageMsg = buildTriageMsg(state);
  const ctrlGates = buildCtrlGates(route, gI, gS, gDone);
  const raceLeft = buildRaceLeft(raceStep);
  const raceRight = buildRaceRight(state, route, routeName);
  const approvalModeHint = buildApprovalModeHint(approvalMode);
  const storyBtnO = isBug ? 0.45 : 1;
  const bugBtnO = isBug ? 1 : 0.45;

  const setTypeStory = () =>
    dispatch({ type: 'SET_TICKET_TYPE', payload: 'story' });
  const setTypeBug = () =>
    dispatch({ type: 'SET_TICKET_TYPE', payload: 'bug' });
  const setStoryPts = (e: ChangeEvent<HTMLInputElement>) =>
    dispatch({ type: 'SET_STORY_PTS', payload: Number(e.target.value) });
  const decThreshold = () => dispatch({ type: 'DEC_THRESHOLD' });
  const incThreshold = () => dispatch({ type: 'INC_THRESHOLD' });
  const cycleMode = () => dispatch({ type: 'CYCLE_MODE' });
  const approveGate = () => {
    if (gS !== 'awaiting' || gDone) return;
    dispatch({ type: 'ADVANCE_GATE' });
  };
  const resetGates = () => dispatch({ type: 'RESTART_GATE' });

  return (
    <section
      className="relative left-1/2 right-1/2 -mx-[50vw] w-screen border-t"
      style={{
        padding: '72px 28px',
        background: 'var(--bg-void)',
        borderColor: 'var(--border-default)',
      }}
    >
      <RevealGroup className="mx-auto text-center" style={{ maxWidth: 760 }}>
        <Reveal>
          <Eyebrow>06 · control</Eyebrow>
        </Reveal>
        <Reveal
          as="h2"
          style={{
            fontSize: 'clamp(30px, 3.8vw, 40px)',
            letterSpacing: '-0.02em',
            color: 'var(--moon-100)',
            margin: '14px 0 16px',
          }}
        >
          You decide how it gets built
        </Reveal>
        <Reveal
          as="p"
          style={{ fontSize: 18, lineHeight: 1.65, color: 'var(--text-muted)' }}
        >
          Most AI dev tools abstract the process away until you can&apos;t see
          what you&apos;re getting — you only find out once the output lands,
          then negotiate your way back to what you meant. nightshift runs the
          opposite way: it keeps the software development lifecycle in front of
          you, with a hard gate at every phase that returns control before the
          next step runs.
        </Reveal>
      </RevealGroup>

      <div className="mx-auto" style={{ maxWidth: 1120 }}>
        <TriageCard
          isStory={isStory}
          isBug={isBug}
          storyBtnO={storyBtnO}
          bugBtnO={bugBtnO}
          storyPts={storyPts}
          threshold={thresh}
          approvalMode={approvalMode}
          approvalModeHint={approvalModeHint}
          triageLanes={triageLanes}
          triageMsg={triageMsg}
          reducedMotion={reducedMotion}
          setTypeStory={setTypeStory}
          setTypeBug={setTypeBug}
          setStoryPts={setStoryPts}
          decThreshold={decThreshold}
          incThreshold={incThreshold}
          cycleMode={cycleMode}
        />

        <GateStrip gates={ctrlGates} reducedMotion={reducedMotion} />

        <ComparisonTerminals
          raceLeft={raceLeft}
          raceRight={raceRight}
          routeName={routeName}
          ctrlAwaiting={ctrlAwaiting}
          ctrlWorking={ctrlWorking}
          ctrlDone={ctrlDone}
          reducedMotion={reducedMotion}
          approveGate={approveGate}
          resetGates={resetGates}
        />
      </div>
    </section>
  );
}

// ---- sub-views (co-located — single state owner, no prop-drilling across files) ----

interface TriageCardProps {
  isStory: boolean;
  isBug: boolean;
  storyBtnO: number;
  bugBtnO: number;
  storyPts: number;
  threshold: number;
  approvalMode: ApprovalMode;
  approvalModeHint: string;
  triageLanes: TriageLane[];
  triageMsg: string;
  reducedMotion: boolean;
  setTypeStory: () => void;
  setTypeBug: () => void;
  setStoryPts: (e: ChangeEvent<HTMLInputElement>) => void;
  decThreshold: () => void;
  incThreshold: () => void;
  cycleMode: () => void;
}

function TriageCard({
  isStory,
  isBug,
  storyBtnO,
  bugBtnO,
  storyPts,
  threshold,
  approvalMode,
  approvalModeHint,
  triageLanes,
  triageMsg,
  reducedMotion,
  setTypeStory,
  setTypeBug,
  setStoryPts,
  decThreshold,
  incThreshold,
  cycleMode,
}: TriageCardProps) {
  return (
    <div
      data-lift
      className="mt-[30px] text-left"
      style={{
        border: '1px solid var(--border-default)',
        background: 'var(--surface-card)',
        padding: '24px 26px',
      }}
    >
      <div
        className="font-mono uppercase"
        style={{
          fontSize: 12,
          letterSpacing: '.16em',
          color: 'var(--accent)',
          marginBottom: 18,
        }}
      >
        // triage — every ticket takes the right-sized path
      </div>
      <div className="grid grid-cols-1 items-start gap-6 lg:grid-cols-[290px_1fr]">
        <div className="flex flex-col gap-3">
          <div
            style={{
              background: 'var(--surface-terminal)',
              border: '1px solid var(--border-accent)',
              padding: '14px 16px',
            }}
          >
            <div className="mb-3 flex items-center justify-between gap-2.5">
              <span
                className="font-mono"
                style={{ fontSize: 13, color: 'var(--moon-100)' }}
              >
                PROJ-142
              </span>
              <div className="flex gap-1.5">
                <button
                  type="button"
                  onClick={setTypeStory}
                  className="font-mono cursor-pointer"
                  style={{
                    fontSize: 11,
                    padding: '3px 10px',
                    opacity: storyBtnO,
                  }}
                >
                  story
                </button>
                <button
                  type="button"
                  onClick={setTypeBug}
                  className="font-mono cursor-pointer"
                  style={{
                    fontSize: 11,
                    padding: '3px 10px',
                    opacity: bugBtnO,
                  }}
                >
                  bug
                </button>
              </div>
            </div>
            {isStory && (
              <div>
                <div className="mb-1.5 flex items-baseline justify-between">
                  <span
                    className="font-mono"
                    style={{ fontSize: 11, color: 'var(--text-dim)' }}
                  >
                    estimate
                  </span>
                  <span
                    className="font-mono"
                    style={{ fontSize: 13, color: 'var(--terra-400)' }}
                  >
                    {storyPts} pts
                  </span>
                </div>
                <input
                  type="range"
                  min={1}
                  max={13}
                  step={1}
                  value={storyPts}
                  onChange={setStoryPts}
                  aria-label="estimate points"
                  className="w-full cursor-pointer"
                  style={{ accentColor: 'var(--terra-500)' }}
                />
                <div
                  className="font-mono flex justify-between"
                  style={{ fontSize: 10, color: 'var(--text-dim)' }}
                >
                  <span>1</span>
                  <span>drag the estimate</span>
                  <span>13</span>
                </div>
              </div>
            )}
            {isBug && (
              <div
                className="font-mono"
                style={{
                  fontSize: 11,
                  letterSpacing: '.1em',
                  color: 'var(--red-400)',
                }}
              >
                DEFECT — no estimate, no spec, no plan
              </div>
            )}
          </div>

          <div
            style={{
              background: 'var(--surface-terminal)',
              border: '1px solid var(--border-default)',
              padding: '14px 16px',
            }}
          >
            <div
              className="font-mono"
              style={{
                fontSize: 11,
                color: 'var(--text-dim)',
                marginBottom: 8,
              }}
            >
              # .claude/project/project-context.md
            </div>
            <div
              className="font-mono flex items-center gap-2.5"
              style={{ fontSize: 13, color: 'var(--moon-200)' }}
            >
              lightweight_threshold:
              <motion.button
                type="button"
                onClick={decThreshold}
                whileTap={reducedMotion ? undefined : { scale: 0.96 }}
                aria-label="decrease lightweight threshold"
                className="font-mono flex cursor-pointer items-center justify-center"
                style={{ width: 26, height: 26, fontSize: 14, padding: 0 }}
              >
                −
              </motion.button>
              <span
                style={{
                  color: 'var(--terra-400)',
                  minWidth: 16,
                  textAlign: 'center',
                }}
              >
                {threshold}
              </span>
              <motion.button
                type="button"
                onClick={incThreshold}
                whileTap={reducedMotion ? undefined : { scale: 0.96 }}
                aria-label="increase lightweight threshold"
                className="font-mono flex cursor-pointer items-center justify-center"
                style={{ width: 26, height: 26, fontSize: 14, padding: 0 }}
              >
                +
              </motion.button>
            </div>
            <div
              className="font-mono mt-2.5 flex flex-wrap items-center gap-2.5"
              style={{ fontSize: 13, color: 'var(--moon-200)' }}
            >
              approval_mode:
              <motion.button
                type="button"
                onClick={cycleMode}
                whileTap={reducedMotion ? undefined : { scale: 0.96 }}
                title="click to cycle: assisted → auto → full-auto"
                className="font-mono cursor-pointer"
                style={{ fontSize: 12, padding: '3px 12px' }}
              >
                {approvalMode} ⟳
              </motion.button>
            </div>
            <div
              className="font-mono mt-1.5"
              style={{ fontSize: 10.5, color: 'var(--text-dim)' }}
            >
              {approvalModeHint}
            </div>
          </div>
        </div>

        <div className="flex flex-col gap-2.5">
          {triageLanes.map((lane) => (
            <div
              key={lane.title}
              className="flex flex-wrap items-center gap-4"
              style={{
                border: `1px solid ${lane.border}`,
                background: lane.bg,
                padding: '14px 18px',
                transition: 'border-color .3s, background .3s',
              }}
            >
              <div style={{ width: 150, flex: 'none' }}>
                <div
                  className="font-mono"
                  style={{
                    fontSize: 13,
                    color: lane.titleColor,
                    transition: 'color .3s',
                  }}
                >
                  {lane.title}
                </div>
                <div
                  className="font-mono"
                  style={{
                    fontSize: 10.5,
                    color: 'var(--text-dim)',
                    marginTop: 3,
                  }}
                >
                  {lane.note}
                </div>
              </div>
              <span
                className="font-mono"
                style={{ fontSize: 13, color: 'var(--moon-300)' }}
              >
                {lane.path}
              </span>
              <div className="ml-auto flex gap-2">
                {lane.tickets.map((t) => (
                  <motion.span
                    key={t.label}
                    className="font-mono"
                    initial={reducedMotion ? false : { opacity: 0, y: 7 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{
                      duration: reducedMotion ? 0 : 0.35,
                      ease: EASE_OUT,
                    }}
                    style={{
                      fontSize: 12,
                      color: t.color,
                      border: `1px solid ${t.border}`,
                      background: t.bg,
                      padding: '4px 10px',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {t.label}
                  </motion.span>
                ))}
              </div>
            </div>
          ))}
          <div
            style={{
              background: 'var(--surface-terminal)',
              border: '1px solid var(--border-soft)',
              padding: '12px 16px',
            }}
          >
            <span
              className="font-mono"
              style={{ fontSize: 12.5, color: 'var(--moon-300)' }}
            >
              {triageMsg}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

function GateStrip({
  gates,
  reducedMotion,
}: {
  gates: CtrlGate[];
  reducedMotion: boolean;
}) {
  return (
    <>
      <div
        className="font-mono uppercase"
        style={{
          fontSize: 11,
          letterSpacing: '.16em',
          color: 'var(--text-dim)',
          margin: '34px 0 4px',
        }}
      >
        // feel a gate — approve each phase yourself
      </div>
      <div className="mx-auto my-1.5 mb-[22px] flex flex-col items-center md:flex-row md:flex-wrap md:items-start md:justify-center">
        {gates.map((g) => (
          <div
            key={g.key}
            className="flex flex-col items-center md:flex-row md:items-start"
          >
            {g.conn && (
              <div
                className="h-[26px] w-px md:mt-[17px] md:h-px md:w-[30px]"
                style={{
                  background: g.connBg,
                  transition: 'background .4s',
                }}
              />
            )}
            <div className="flex flex-col items-center gap-2 px-[14px] py-2.5 md:py-0">
              <motion.span
                className="font-mono flex items-center justify-center"
                animate={
                  g.awaiting && !reducedMotion
                    ? GATE_PULSE_ANIMATE
                    : { scale: 1, filter: 'brightness(1)' }
                }
                transition={
                  g.awaiting && !reducedMotion
                    ? { duration: 1.3, ease: 'easeInOut', repeat: Infinity }
                    : { duration: 0.2 }
                }
                style={{
                  width: 34,
                  height: 34,
                  borderRadius: '50%',
                  border: `1px solid ${g.border}`,
                  background: g.bg,
                  color: g.color,
                  fontSize: 16,
                  boxShadow: g.glow,
                  transition:
                    'background .4s, border-color .4s, color .4s, box-shadow .4s',
                }}
              >
                {g.done ? <GateCheck reduced={reducedMotion} /> : g.glyph}
              </motion.span>
              <span
                className="font-mono"
                style={{
                  fontSize: 13,
                  color: g.labelColor,
                  transition: 'color .4s',
                }}
              >
                {g.label}
              </span>
            </div>
          </div>
        ))}
      </div>
    </>
  );
}

interface ComparisonTerminalsProps {
  raceLeft: RaceLine[];
  raceRight: { t: string; color: string }[];
  routeName: string;
  ctrlAwaiting: boolean;
  ctrlWorking: boolean;
  ctrlDone: boolean;
  reducedMotion: boolean;
  approveGate: () => void;
  resetGates: () => void;
}

// Matches the retired `ns-risein` keyframes (.4s rise from y:7 + fade in).
function riseInProps(reducedMotion: boolean, durationS = 0.4) {
  return {
    initial: reducedMotion ? false : { opacity: 0, y: 7 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: reducedMotion ? 0 : durationS, ease: EASE_OUT },
  } as const;
}

function ComparisonTerminals({
  raceLeft,
  raceRight,
  routeName,
  ctrlAwaiting,
  ctrlWorking,
  ctrlDone,
  reducedMotion,
  approveGate,
  resetGates,
}: ComparisonTerminalsProps) {
  return (
    <>
      <div
        className="font-mono uppercase"
        style={{
          fontSize: 11,
          letterSpacing: '.16em',
          color: 'var(--text-dim)',
          margin: '40px 0 14px',
        }}
      >
        // the same ticket, both ways — routed by the config above
      </div>
      <div
        className="mx-auto mb-[26px] grid grid-cols-1 gap-[18px] text-left lg:grid-cols-2"
        style={{ maxWidth: 1120 }}
      >
        <div
          className="flex flex-col items-stretch gap-2.5"
          style={{
            background: 'var(--surface-terminal)',
            border: '1px solid var(--border-default)',
            padding: '24px 26px',
            minHeight: 480,
          }}
        >
          <div
            className="font-mono uppercase"
            style={{
              fontSize: 11.5,
              letterSpacing: '.14em',
              color: 'var(--text-dim)',
              borderBottom: '1px solid var(--border-soft)',
              paddingBottom: 10,
              marginBottom: 2,
            }}
          >
            one-shot AI
          </div>
          {raceLeft.map((r, idx) =>
            'blob' in r ? (
              <motion.div
                key={idx}
                className="flex flex-col gap-1.5"
                initial={
                  reducedMotion ? false : { opacity: 0, y: -18, scale: 1.05 }
                }
                animate={{ opacity: 1, y: [-18, 2, 0], scale: [1.05, 1, 1] }}
                transition={{
                  duration: reducedMotion ? 0 : 0.5,
                  ease: EASE_OUT,
                  times: [0, 0.6, 1],
                }}
                style={{
                  background: 'rgba(255,255,255,.03)',
                  border: '1px solid var(--border-soft)',
                  padding: '10px 12px',
                }}
              >
                <span
                  className="font-mono"
                  style={{ fontSize: 11, color: 'var(--text-dim)' }}
                >
                  db29f1c · feat: PROJ-142 · 1 commit · 96 files
                </span>
                {[
                  ['████████████████████▌', '████████▌'],
                  ['███████████▌', '██████████████▌'],
                  ['████████████████████████▌', '██▌'],
                  ['█████████▌', '███████████▌'],
                  ['███████████████▌', '█████▌'],
                ].map(([plus, minus], row) => (
                  <span
                    key={row}
                    className="font-mono"
                    style={{ fontSize: 11, letterSpacing: '-1px' }}
                  >
                    <span style={{ color: 'rgba(110,196,138,.55)' }}>
                      +{plus}
                    </span>{' '}
                    <span style={{ color: 'rgba(224,101,111,.5)' }}>
                      −{minus}
                    </span>
                  </span>
                ))}
              </motion.div>
            ) : (
              <motion.div key={idx} {...riseInProps(reducedMotion)}>
                <span
                  className="font-mono block"
                  style={{ fontSize: 14.5, lineHeight: 1.75, color: r.color }}
                >
                  {r.t}
                </span>
              </motion.div>
            ),
          )}
        </div>

        <div
          className="flex flex-col items-stretch gap-2.5"
          style={{
            background: 'var(--surface-terminal)',
            border: '1px solid var(--border-accent)',
            boxShadow: '0 0 22px rgba(217,119,87,.12)',
            padding: '24px 26px',
            minHeight: 480,
          }}
        >
          <div
            className="font-mono uppercase"
            style={{
              fontSize: 11.5,
              letterSpacing: '.14em',
              color: 'var(--accent)',
              borderBottom: '1px solid var(--border-soft)',
              paddingBottom: 10,
              marginBottom: 2,
            }}
          >
            🌙 nightshift · {routeName}
          </div>
          {raceRight.map((r, idx) => (
            <motion.div key={idx} {...riseInProps(reducedMotion)}>
              <span
                className="font-mono block"
                style={{ fontSize: 14.5, lineHeight: 1.75, color: r.color }}
              >
                {r.t}
              </span>
            </motion.div>
          ))}
          {ctrlAwaiting && (
            <div className="mt-auto flex justify-end pt-2.5">
              <motion.span
                className="inline-block"
                whileTap={reducedMotion ? undefined : { scale: 0.96 }}
              >
                <CtaButton variant="primary" size="sm" onClick={approveGate}>
                  approve ✓
                </CtaButton>
              </motion.span>
            </div>
          )}
          {ctrlWorking && (
            <div className="mt-auto flex justify-end pt-2.5">
              <motion.span
                className="font-mono"
                animate={reducedMotion ? undefined : TWINKLE_ANIMATE}
                transition={
                  reducedMotion
                    ? undefined
                    : { duration: 1.2, ease: 'easeInOut', repeat: Infinity }
                }
                style={{ fontSize: 12, color: 'var(--text-dim)' }}
              >
                ▌ working
              </motion.span>
            </div>
          )}
          {ctrlDone && (
            <div className="mt-auto flex justify-end pt-2.5">
              <CtaButton variant="secondary" size="sm" onClick={resetGates}>
                run it again ↺
              </CtaButton>
            </div>
          )}
        </div>
      </div>
      <a
        href="/why-sdlc"
        className="font-mono"
        style={{ fontSize: 16, color: 'var(--link)' }}
      >
        Why an SDLC beats one-shot AI →
      </a>
    </>
  );
}
