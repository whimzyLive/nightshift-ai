'use client';

import { useEffect, useRef, useState } from 'react';
import { animate, motion, useMotionValue } from 'motion/react';

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
}

export type TerminalLineTone = 'default' | 'muted' | 'accent' | 'success';

export interface TerminalLine {
  /** Optional prompt glyph (e.g. '$') rendered before the text. */
  prompt?: string;
  /** Optional agent label rendered as a colored tag before the text. */
  agent?: string;
  /** Line body text. */
  text: string;
  /** Semantic color tone. Default: 'default'. */
  tone?: TerminalLineTone;
  /** Indent depth (each level = one step of left padding). Default: 0. */
  indent?: number;
}

export interface TerminalProps {
  /** Chrome title-bar caption. */
  title: string;
  /** The scripted lines, revealed in order. */
  lines: readonly TerminalLine[];
  /**
   * Min height of the body — a px number, or any CSS length (e.g. a
   * `clamp(...)` string) to reserve space / scale with the viewport.
   */
  minHeight?: number | string;
  className?: string;
}

const REVEAL_MS = 520; // --dur-terminal-line
const REVEAL_S = REVEAL_MS / 1000;
const CARET_BLINK_S = 0.5;
const INDENT_STEP_PX = 16;

const TONE_COLOR: Record<TerminalLineTone, string> = {
  default: 'var(--text-body)',
  muted: 'var(--text-dim)',
  accent: 'var(--accent)',
  success: 'var(--success)',
};

/**
 * Faux terminal that plays a scripted line-by-line run on loop, with a
 * magnetic pointer tilt and a slow ambient idle drift — all driven by Motion.
 * Deterministic server frame renders line 1 only, matching the
 * `night-sky.tsx` hydration pattern. Everything is skipped under
 * `prefers-reduced-motion` (the full run renders immediately, no tilt/drift).
 */
export function Terminal({
  title,
  lines,
  minHeight = 360,
  className = '',
}: TerminalProps) {
  const [visibleCount, setVisibleCount] = useState(1);
  const [hovering, setHovering] = useState(false);
  const [replayNonce, setReplayNonce] = useState(0);
  const wrapRef = useRef<HTMLDivElement>(null);

  // 3D transform driven by Motion values: tilt on hover, idle drift otherwise.
  const rotateX = useMotionValue(0);
  const rotateY = useMotionValue(0);
  const lift = useMotionValue(0);

  // Reveal cadence + loop — a single Motion tween of a counter, looping.
  useEffect(() => {
    if (prefersReducedMotion()) {
      setVisibleCount(lines.length);
      return;
    }
    setVisibleCount(1);
    const total = lines.length;
    // Reveal once, then stop (no infinite loop — that kept burning frames).
    // onUpdate fires ~60/s; only push state when the revealed count changes,
    // so React re-renders ~once per line. `replayNonce` re-runs it on demand.
    let lastCount = 1;
    const controls = animate(0, total, {
      duration: total * REVEAL_S,
      ease: 'linear',
      onUpdate: (v) => {
        const next = Math.min(total, Math.max(1, Math.floor(v) + 1));
        if (next !== lastCount) {
          lastCount = next;
          setVisibleCount(next);
        }
      },
      onComplete: () => setVisibleCount(total),
    });
    return () => controls.stop();
  }, [lines.length, replayNonce]);

  // Magnetic tilt on hover; idle drift when not hovered. Both operate on the
  // same Motion values and are mutually exclusive.
  useEffect(() => {
    if (prefersReducedMotion()) return;
    const el = wrapRef.current;
    if (!el) return;

    const onPointerMove = (event: PointerEvent) => {
      if (!hovering) return;
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;
      const px = (event.clientX - rect.left) / rect.width - 0.5;
      const py = (event.clientY - rect.top) / rect.height - 0.5;
      rotateX.set(-py * 8);
      rotateY.set(px * 10);
      lift.set(0);
    };
    const onPointerEnter = () => setHovering(true);
    const onPointerLeave = () => setHovering(false);

    el.addEventListener('pointermove', onPointerMove);
    el.addEventListener('pointerenter', onPointerEnter);
    el.addEventListener('pointerleave', onPointerLeave);
    return () => {
      el.removeEventListener('pointermove', onPointerMove);
      el.removeEventListener('pointerenter', onPointerEnter);
      el.removeEventListener('pointerleave', onPointerLeave);
    };
  }, [hovering, rotateX, rotateY, lift]);

  // Idle ambient drift — runs only while not hovered; Motion tweens revert
  // the values back to rest on hover / cleanup.
  useEffect(() => {
    if (prefersReducedMotion() || hovering) return;
    const dx = animate(rotateX, 0, { duration: 0.4, ease: 'easeOut' });
    const drift = animate(rotateY, [-1.4, 1.4], {
      duration: 3.6,
      ease: 'easeInOut',
      repeat: Infinity,
      repeatType: 'reverse',
    });
    const bob = animate(lift, [-4, 4], {
      duration: 5.2,
      ease: 'easeInOut',
      repeat: Infinity,
      repeatType: 'reverse',
    });
    return () => {
      dx.stop();
      drift.stop();
      bob.stop();
    };
  }, [hovering, rotateX, rotateY, lift]);

  const visible = lines.slice(0, visibleCount);
  const finalIndex = lines.length - 1;
  const fullyRevealed = visibleCount >= lines.length;

  return (
    <motion.div
      ref={wrapRef}
      className={`rounded-none border ${className}`}
      style={{
        rotateX,
        rotateY,
        y: lift,
        transformPerspective: 900,
        borderColor: 'var(--border-default)',
        background: 'var(--surface-terminal)',
        transformStyle: 'preserve-3d',
      }}
    >
      <p className="sr-only">
        Terminal preview: {'/auto PROJ-142'} runs the full delivery pipeline —
        reads the ticket, drafts the spec and plan, implements across
        specialized agents, passes the QA gate, and opens a reviewed pull
        request.
      </p>
      <div
        className="flex items-center gap-2 border-b px-3.5 py-2.5"
        style={{
          borderColor: 'var(--border-default)',
          background: 'rgba(255,255,255,0.03)',
        }}
      >
        <span aria-hidden="true" className="flex gap-1.5">
          <span
            className="size-2.5 rounded-full"
            style={{ background: 'var(--red-400)' }}
          />
          <span
            className="size-2.5 rounded-full"
            style={{ background: 'var(--amber-400)' }}
          />
          <span
            className="size-2.5 rounded-full"
            style={{ background: 'var(--green-400)' }}
          />
        </span>
        <span
          className="truncate font-mono text-xs"
          style={{ color: 'var(--text-dim)' }}
        >
          {title}
        </span>
        {fullyRevealed && (
          <button
            type="button"
            onClick={() => setReplayNonce((n) => n + 1)}
            aria-label="Replay the terminal run"
            className="ml-auto flex-none rounded-none border border-[var(--border-default)] px-2 py-0.5 font-mono text-[11px] tracking-[0.04em] text-[var(--text-dim)] uppercase transition-colors duration-150 ease-out hover:border-[var(--link)] hover:text-[var(--text-strong)] focus-visible:outline-none focus-visible:shadow-[var(--glow-focus)] motion-reduce:transition-none"
          >
            ↺ replay
          </button>
        )}
      </div>
      <div
        aria-hidden="true"
        className="overflow-hidden px-4 py-4 font-mono text-sm leading-relaxed"
        style={{ minHeight }}
      >
        {visible.map((line, idx) => {
          const color = TONE_COLOR[line.tone ?? 'default'];
          const isCaret =
            idx === finalIndex && fullyRevealed && !prefersReducedMotion();
          return (
            <div
              key={idx}
              style={{ paddingLeft: (line.indent ?? 0) * INDENT_STEP_PX }}
            >
              {line.prompt && (
                <span style={{ color: 'var(--code-prompt)', marginRight: 8 }}>
                  {line.prompt}
                </span>
              )}
              {line.agent && <span style={{ color }}>{line.agent} </span>}
              <motion.span
                style={{ color }}
                animate={isCaret ? { opacity: [1, 0, 1] } : { opacity: 1 }}
                transition={
                  isCaret
                    ? {
                        duration: CARET_BLINK_S * 2,
                        ease: 'linear',
                        repeat: Infinity,
                      }
                    : { duration: 0 }
                }
              >
                {line.text || ' '}
              </motion.span>
            </div>
          );
        })}
      </div>
    </motion.div>
  );
}
