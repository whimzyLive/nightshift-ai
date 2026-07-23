'use client';

import { useEffect, useRef, useState } from 'react';

import {
  motion,
  useMotionValueEvent,
  useScroll,
  useTransform,
} from 'motion/react';

import { EASE_OUT, prefersReducedMotion } from '@nightshift-ai/ui';

type StageStatus = 'done' | 'active' | 'idle';

interface PipelineStage {
  command: string;
  label: string;
  agent: string;
  /**
   * Reduced-motion fallback composition — the pipeline's original hardcoded
   * per-stage status, rendered as-is (no scroll-driven index) when reduced.
   */
  status: StageStatus;
}

// The spec→plan→impl→review→PR pipeline, verbatim from the design handoff
// (nightshift Landing.dc.html `pipelineStages`). Each stage carries its
// command, human label, owning agent, and its reduced-motion fallback status.
const PIPELINE: PipelineStage[] = [
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
];

const STAGE_STYLE: Record<
  StageStatus,
  { border: string; cmd: string; glow?: string }
> = {
  done: { border: 'rgba(110,196,138,0.35)', cmd: 'var(--success)' },
  active: {
    border: 'var(--border-accent)',
    cmd: 'var(--terra-400)',
    glow: 'var(--glow-accent)',
  },
  idle: { border: 'var(--border-default)', cmd: 'var(--text-muted)' },
};

const BAND_COUNT = PIPELINE.length;
// Matches the `--dur-base` token (200ms).
const GLOW_TRANSITION_S = 0.2;

function bandIndex(progress: number): number {
  return Math.min(
    BAND_COUNT - 1,
    Math.max(0, Math.floor(progress * BAND_COUNT)),
  );
}

/**
 * A2 — the 5-stage pipeline strip, scoped-scroll-linked: `useScroll` tracks
 * this strip's own scroll progress through the viewport, `useTransform`
 * derives a discrete stage index from progress crossing each of 5 equal
 * bands, and `useMotionValueEvent` bridges that MotionValue into React state
 * (needed to switch each stage's static `STAGE_STYLE` treatment). The
 * travelling glow is a pre-rendered `--glow-accent` layer, painted once as a
 * static `boxShadow` and cross-faded via `opacity` only between stages — the
 * `boxShadow` itself is never animated (paint-bound, forbidden by the perf
 * envelope). Reduced motion renders each stage's original hardcoded
 * `status` (today's static composition) with no scroll-driven index change.
 */
export function PipelineStrip() {
  const containerRef = useRef<HTMLDivElement>(null);
  const [reduced, setReduced] = useState(false);
  useEffect(() => setReduced(prefersReducedMotion()), []);

  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ['start end', 'end start'],
  });
  const bandMV = useTransform(scrollYProgress, bandIndex);
  const [activeIndex, setActiveIndex] = useState(0);
  useMotionValueEvent(bandMV, 'change', (latest) => setActiveIndex(latest));

  return (
    <div
      ref={containerRef}
      className="mb-9 flex flex-col items-stretch md:flex-row md:flex-wrap md:items-stretch md:justify-center"
    >
      {PIPELINE.map((stage, i) => {
        const status: StageStatus = reduced
          ? stage.status
          : i < activeIndex
            ? 'done'
            : i === activeIndex
              ? 'active'
              : 'idle';
        const s = STAGE_STYLE[status];
        return (
          <div
            key={stage.command}
            className="flex flex-col items-stretch md:flex-row"
          >
            <div
              data-lift
              data-stage-status={status}
              className="relative flex w-full flex-col gap-1.5 text-center md:w-auto md:text-left"
              style={{
                minWidth: 148,
                padding: '14px 16px',
                background: 'var(--surface-card)',
                border: '1px solid',
                borderColor: s.border,
                boxShadow:
                  'var(--elev-2), inset 0 1px 0 rgba(255,255,255,0.05)',
              }}
            >
              {/* Pre-rendered glow layer — `--glow-accent` painted once as a
                  static box-shadow, cross-faded between stages via `opacity`
                  only. The box-shadow itself is never tweened. */}
              <motion.span
                aria-hidden="true"
                className="pointer-events-none absolute inset-0"
                style={{ boxShadow: 'var(--glow-accent)' }}
                animate={{ opacity: status === 'active' ? 1 : 0 }}
                transition={{
                  duration: reduced ? 0 : GLOW_TRANSITION_S,
                  ease: EASE_OUT,
                }}
              />
              <span
                className="font-mono relative font-medium"
                style={{ fontSize: 13, color: s.cmd }}
              >
                {status === 'done' ? '✓ ' : ''}
                {stage.command}
              </span>
              <span
                className="relative"
                style={{ fontSize: 13, color: 'var(--text-strong)' }}
              >
                {stage.label}
              </span>
              <span
                className="font-mono relative"
                style={{ fontSize: 11, color: 'var(--text-dim)' }}
              >
                {stage.agent}
              </span>
            </div>
            {i < PIPELINE.length - 1 && (
              <span
                aria-hidden="true"
                className="flex rotate-90 items-center justify-center py-1.5 font-mono md:rotate-0 md:justify-start md:px-1.5 md:py-0"
                style={{
                  fontSize: 14,
                  color:
                    status === 'done' ? 'var(--success)' : 'var(--moon-500)',
                }}
              >
                →
              </span>
            )}
          </div>
        );
      })}
    </div>
  );
}
