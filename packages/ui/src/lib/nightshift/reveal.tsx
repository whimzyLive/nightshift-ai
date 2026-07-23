'use client';

import { motion } from 'motion/react';
import { useEffect, useState } from 'react';
import type { CSSProperties, ReactNode } from 'react';

import { EASE_OUT } from './motion-tokens';
import { prefersReducedMotion } from './prefers-reduced-motion';

type MotionTag =
  | 'div'
  | 'section'
  | 'span'
  | 'li'
  | 'article'
  | 'h2'
  | 'h3'
  | 'p';

export interface RevealGroupProps {
  children: ReactNode;
  /** Seconds between each child's reveal. */
  stagger?: number;
  /** Seconds to wait before the first child reveals. */
  delayChildren?: number;
  /** Fraction of the group that must be in view before it triggers (0–1). */
  amount?: number;
  as?: MotionTag;
  className?: string;
  style?: CSSProperties;
  /** Forwarded to the DOM node (e.g. `data-lift`, `aria-*`). */
  [key: `data-${string}`]: unknown;
}

/**
 * Orchestrates a staggered scroll reveal for its {@link Reveal} children.
 * Triggers once when `amount` of the group scrolls into view, then fades +
 * rises each child in sequence. Under `prefers-reduced-motion` the whole group
 * renders in its final state immediately (no motion). GPU-only (opacity +
 * transform) so it stays at 60fps.
 */
export function RevealGroup({
  children,
  stagger = 0.09,
  delayChildren = 0,
  amount = 0.25,
  as = 'div',
  className,
  style,
  ...rest
}: RevealGroupProps) {
  const [reduced, setReduced] = useState(false);
  useEffect(() => setReduced(prefersReducedMotion()), []);

  const Comp = motion[as];

  return (
    <Comp
      className={className}
      style={style}
      {...rest}
      variants={{
        hidden: {},
        shown: {
          transition: {
            staggerChildren: reduced ? 0 : stagger,
            delayChildren: reduced ? 0 : delayChildren,
          },
        },
      }}
      initial="hidden"
      whileInView="shown"
      viewport={{ once: true, amount }}
    >
      {children}
    </Comp>
  );
}

export interface RevealSpring {
  stiffness: number;
  damping: number;
}

export interface RevealProps {
  children: ReactNode;
  /** Upward travel distance in px (transform — no layout shift). */
  y?: number;
  /** Start scale (1 = none). Slight <1 gives a soft settle-into-place. */
  scale?: number;
  /**
   * Start blur in px (0 = none). A small value "frosts" the element in and
   * sharpens — pairs with a glassmorphic surface for a materialise effect.
   */
  blur?: number;
  /** Reveal duration in seconds. Ignored when `spring` is set. */
  duration?: number;
  /**
   * Opt-in spring config for the shown transition, replacing the default
   * `duration`/`EASE_OUT` tween with a gentle settle spring — exempt from
   * `EASE_OUT` (spring-driven), stays transform/opacity-only. Does not
   * change the reduced-motion identity-variants latch below, or the `y`
   * travel distance.
   */
  spring?: RevealSpring;
  as?: MotionTag;
  className?: string;
  style?: CSSProperties;
  /** Forwarded to the DOM node (e.g. `data-lift`, `aria-*`). */
  [key: `data-${string}`]: unknown;
}

/**
 * A single reveal item — must be rendered inside a {@link RevealGroup}, which
 * drives its timing. Fades in and rises `y`px into place, optionally settling
 * from a slight `scale` and `blur` for a glassmorphic frost-in. Its `variants`
 * collapse to identity under reduced motion so it renders statically visible.
 */
export function Reveal({
  children,
  y = 16,
  scale = 1,
  blur = 0,
  duration = 0.55,
  spring,
  as = 'div',
  className,
  style,
  ...rest
}: RevealProps) {
  const [reduced, setReduced] = useState(false);
  useEffect(() => setReduced(prefersReducedMotion()), []);

  const Comp = motion[as];
  const blurFrom = blur ? `blur(${blur}px)` : undefined;
  const blurTo = blur ? 'blur(0px)' : undefined;
  const shownTransition = spring
    ? {
        type: 'spring' as const,
        stiffness: spring.stiffness,
        damping: spring.damping,
      }
    : { duration, ease: EASE_OUT };

  return (
    <Comp
      className={className}
      style={style}
      {...rest}
      variants={
        reduced
          ? // Reduced motion: identity variants — the parent still drives the
            // `hidden`→`shown` label, but the item never moves, scales, or fades.
            {
              hidden: { opacity: 1, y: 0, scale: 1, filter: blurTo },
              shown: { opacity: 1, y: 0, scale: 1, filter: blurTo },
            }
          : {
              hidden: { opacity: 0, y, scale, filter: blurFrom },
              shown: {
                opacity: 1,
                y: 0,
                scale: 1,
                filter: blurTo,
                transition: shownTransition,
              },
            }
      }
    >
      {children}
    </Comp>
  );
}
