'use client';

import { useEffect, useRef, useState } from 'react';

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
  /** Min height of the body in px (reserve space to avoid layout shift). */
  minHeight?: number;
  className?: string;
}

const REVEAL_MS = 520; // --dur-terminal-line
const INDENT_STEP_PX = 16;

const TONE_COLOR: Record<TerminalLineTone, string> = {
  default: 'var(--text-body)',
  muted: 'var(--text-dim)',
  accent: 'var(--accent)',
  success: 'var(--success)',
};

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
}

/**
 * Faux terminal that plays a scripted line-by-line run on loop, with a
 * magnetic pointer tilt and a slow ambient idle drift. Deterministic server
 * frame renders line 1 only, matching the `night-sky.tsx` hydration pattern.
 * Every JS-driven effect self-checks `prefers-reduced-motion` before wiring
 * any timer or pointer listener.
 */
export function Terminal({
  title,
  lines,
  minHeight = 360,
  className = '',
}: TerminalProps) {
  const [visibleCount, setVisibleCount] = useState(1);
  const [hovering, setHovering] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const driftFrame = useRef<number | null>(null);

  // Reveal cadence + loop.
  useEffect(() => {
    if (prefersReducedMotion()) {
      setVisibleCount(lines.length);
      return;
    }
    const id = setInterval(() => {
      setVisibleCount((count) => (count >= lines.length ? 1 : count + 1));
    }, REVEAL_MS);
    return () => clearInterval(id);
  }, [lines.length]);

  // Magnetic tilt on hover — bail entirely under reduced motion (no
  // listeners wired at all, not just a suppressed CSS transition).
  useEffect(() => {
    if (prefersReducedMotion()) return;
    const el = wrapRef.current;
    if (!el) return;

    const onPointerMove = (event: PointerEvent) => {
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;
      const px = (event.clientX - rect.left) / rect.width - 0.5;
      const py = (event.clientY - rect.top) / rect.height - 0.5;
      el.style.transform = `perspective(900px) rotateX(${(-py * 8).toFixed(2)}deg) rotateY(${(px * 10).toFixed(2)}deg)`;
    };
    const onPointerEnter = () => setHovering(true);
    const onPointerLeave = () => {
      setHovering(false);
      el.style.transform = '';
    };

    el.addEventListener('pointermove', onPointerMove);
    el.addEventListener('pointerenter', onPointerEnter);
    el.addEventListener('pointerleave', onPointerLeave);
    return () => {
      el.removeEventListener('pointermove', onPointerMove);
      el.removeEventListener('pointerenter', onPointerEnter);
      el.removeEventListener('pointerleave', onPointerLeave);
    };
  }, []);

  // Ambient idle drift while not hovered — also skipped under reduced
  // motion, and defensively no-ops if requestAnimationFrame is unsupported.
  useEffect(() => {
    if (prefersReducedMotion() || hovering) return;
    if (typeof window === 'undefined' || !window.requestAnimationFrame) return;
    const el = wrapRef.current;
    if (!el) return;

    const start = performance.now();
    const tick = (now: number) => {
      const t = (now - start) / 1000;
      const rotate = Math.sin(t * 0.5) * 1.4;
      const lift = Math.sin(t * 0.35) * 4;
      el.style.transform = `perspective(900px) rotateY(${rotate.toFixed(2)}deg) translateY(${lift.toFixed(2)}px)`;
      driftFrame.current = window.requestAnimationFrame(tick);
    };
    driftFrame.current = window.requestAnimationFrame(tick);
    return () => {
      if (driftFrame.current !== null)
        window.cancelAnimationFrame(driftFrame.current);
    };
  }, [hovering]);

  const visible = lines.slice(0, visibleCount);
  const finalIndex = lines.length - 1;

  return (
    <div
      ref={wrapRef}
      className={`rounded-none border ${className}`}
      style={{
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
      </div>
      <div
        aria-hidden="true"
        className="overflow-hidden px-4 py-4 font-mono text-sm leading-relaxed"
        style={{ minHeight }}
      >
        {visible.map((line, idx) => {
          const isCaretLine = idx === finalIndex && visibleCount > finalIndex;
          const color = TONE_COLOR[line.tone ?? 'default'];
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
              <span
                style={{ color }}
                className={
                  isCaretLine ? 'animate-[ns-blink_1s_step-end_infinite]' : ''
                }
              >
                {line.text || ' '}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
