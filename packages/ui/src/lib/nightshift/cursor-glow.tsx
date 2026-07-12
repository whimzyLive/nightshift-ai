'use client';

import { useEffect, useState } from 'react';
import { motion, useMotionValue, useSpring } from 'motion/react';

const INTERACTIVE_SELECTOR =
  'a,button,[role="button"],input,textarea,select,summary';

const FOLLOW = { stiffness: 500, damping: 40, mass: 0.5 } as const;

/**
 * 28px radial terracotta glow tracking the pointer, growing to ~84px over
 * interactive elements. Renders nothing on coarse pointers (touch) or
 * under `prefers-reduced-motion` — both checked before any listener
 * attaches, so there's no dead DOM node left behind either way. Follow is a
 * spring-smoothed Motion value.
 */
export function CursorGlow() {
  const [enabled, setEnabled] = useState(false);
  const [active, setActive] = useState(false);

  const x = useMotionValue(0);
  const y = useMotionValue(0);
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

  const size = active ? 'var(--cursor-size-active)' : 'var(--cursor-size)';
  const background = active
    ? 'radial-gradient(circle, var(--cursor-glow-active), rgba(124,147,240,0.16) 58%, transparent 72%)'
    : 'radial-gradient(circle, var(--cursor-glow), transparent 70%)';

  return (
    <motion.div
      aria-hidden="true"
      className="pointer-events-none fixed top-0 left-0 z-[9998] rounded-full transition-[width,height,background] duration-200 ease-out motion-reduce:transition-none"
      style={{
        x: sx,
        y: sy,
        width: size,
        height: size,
        marginTop: active
          ? 'calc(var(--cursor-size-active) / -2)'
          : 'calc(var(--cursor-size) / -2)',
        marginLeft: active
          ? 'calc(var(--cursor-size-active) / -2)'
          : 'calc(var(--cursor-size) / -2)',
        background,
        mixBlendMode: 'screen',
        willChange: 'transform',
      }}
    />
  );
}
