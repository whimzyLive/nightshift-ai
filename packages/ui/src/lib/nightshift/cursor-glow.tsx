'use client';

import { useEffect, useState } from 'react';
import { motion, useMotionValue, useSpring } from 'motion/react';

const INTERACTIVE_SELECTOR =
  'a,button,[role="button"],input,textarea,select,summary';

// Connector springs off the raw cursor with lag, so it trails behind the
// lead dot instead of tracking it exactly.
const TRAIL = { stiffness: 260, damping: 26, mass: 0.6 } as const;
// The large spotlight follows more tightly than the trail dot.
const FOLLOW = { stiffness: 500, damping: 40, mass: 0.5 } as const;

/**
 * Pointer trail + focus spotlight. A tiny solid lead dot pinned to the true
 * cursor, one spring-following connector dot trailing behind it, and a large
 * radial spotlight that spring-follows the pointer — small at rest, growing
 * to a bright focus glow over any clickable element (link, button, input,
 * …). Renders nothing on coarse pointers (touch) or under
 * `prefers-reduced-motion` — both checked before any listener attaches, so
 * there's no dead DOM node left behind either way.
 */
export function CursorGlow() {
  const [enabled, setEnabled] = useState(false);
  const [active, setActive] = useState(false);

  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const tx = useSpring(x, TRAIL);
  const ty = useSpring(y, TRAIL);
  const sx = useSpring(x, FOLLOW);
  const sy = useSpring(y, FOLLOW);

  useEffect(() => {
    const fine = window.matchMedia('(pointer: fine)');
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
    setEnabled(fine.matches && !reduced.matches);

    const onFineChange = () => setEnabled(fine.matches && !reduced.matches);
    fine.addEventListener('change', onFineChange);
    reduced.addEventListener('change', onFineChange);
    return () => {
      fine.removeEventListener('change', onFineChange);
      reduced.removeEventListener('change', onFineChange);
    };
  }, []);

  useEffect(() => {
    if (!enabled) return;

    const onMove = (event: PointerEvent) => {
      x.set(event.clientX);
      y.set(event.clientY);
      const target = event.target as Element | null;
      setActive(Boolean(target?.closest?.(INTERACTIVE_SELECTOR)));
    };

    window.addEventListener('pointermove', onMove, { passive: true });
    return () => window.removeEventListener('pointermove', onMove);
  }, [enabled, x, y]);

  if (!enabled) return null;

  // Rest size ÷ active size (56 / 84) — the spotlight is a fixed active-size
  // element scaled down at rest, so the size change animates on `transform`
  // (GPU) instead of width/height (layout + paint). Rest blob is 2× the base
  // --cursor-size (28 → 56).
  const REST_SCALE = 56 / 84;

  return (
    <>
      {/* Large focus spotlight — grows + brightens over clickable elements.
          Scale/opacity only, so it stays on the compositor. */}
      <motion.div
        aria-hidden="true"
        className="pointer-events-none fixed top-0 left-0 z-[9997] rounded-full"
        style={{
          x: sx,
          y: sy,
          width: 'var(--cursor-size-active)',
          height: 'var(--cursor-size-active)',
          marginTop: 'calc(var(--cursor-size-active) / -2)',
          marginLeft: 'calc(var(--cursor-size-active) / -2)',
          background:
            'radial-gradient(circle, var(--cursor-glow-active), rgba(124,147,240,0.16) 58%, transparent 72%)',
          mixBlendMode: 'screen',
          willChange: 'transform',
        }}
        animate={{ scale: active ? 1 : REST_SCALE, opacity: active ? 1 : 0.6 }}
        transition={{ duration: 0.2, ease: 'easeOut' }}
      />
      {/* Connector dot — trails behind the cursor. */}
      <motion.div
        aria-hidden="true"
        className="pointer-events-none fixed top-0 left-0 z-[9998] rounded-full"
        style={{
          x: tx,
          y: ty,
          width: 6,
          height: 6,
          marginTop: -3,
          marginLeft: -3,
          background: 'var(--accent)',
          opacity: 0.5,
          mixBlendMode: 'screen',
          willChange: 'transform',
        }}
      />
      {/* Tiny lead dot pinned to the true cursor. */}
      <motion.div
        aria-hidden="true"
        className="pointer-events-none fixed top-0 left-0 z-[9999] rounded-full"
        style={{
          x,
          y,
          width: 5,
          height: 5,
          marginTop: -2.5,
          marginLeft: -2.5,
          background: 'var(--accent)',
          boxShadow: '0 0 6px var(--cursor-glow)',
          willChange: 'transform',
        }}
      />
    </>
  );
}
