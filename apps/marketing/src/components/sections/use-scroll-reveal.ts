'use client';

import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

import { useIsomorphicLayoutEffect } from './use-isomorphic-layout-effect';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

export interface UseScrollRevealOptions {
  /**
   * Returns the section/container the ScrollTrigger watches to fire the
   * reveal. A lazy getter (not the resolved element) so the ref is read
   * inside the effect, after refs commit — not at render time.
   */
  getTrigger: () => Element | null | undefined;
  /** Returns the element(s) tweened from hidden to visible. Same lazy-read reason as `getTrigger`. */
  getTargets: () => Array<Element | null | undefined>;
  /** Stagger between multiple targets, in seconds. @default 0 */
  stagger?: number;
  /** ScrollTrigger start position. @default 'top 75%' */
  start?: string;
}

/**
 * Shared "reveal on scroll" scaffold reused by every section that fades +
 * lifts its content in once per page view (AC3): transform/opacity only,
 * 120-360ms, one ease (power3.out) — the brand motion budget.
 *
 * `clearProps` on the reveal tween strips the inline transform/opacity/
 * visibility GSAP leaves on the target after a `gsap.from` completes.
 * Without it, that inline residue permanently outranks any CSS-module
 * `:hover` transform on the same element (AC4 hover-lift regression).
 *
 * The reduced-motion branch is a deliberate no-op: targets are visible by
 * default in CSS (nothing ever hid them in this branch), so there is
 * nothing to reveal and nothing to reset.
 */
export function useScrollReveal(
  {
    getTrigger,
    getTargets,
    stagger = 0,
    start = 'top 75%',
  }: UseScrollRevealOptions,
  deps: unknown[],
): void {
  useIsomorphicLayoutEffect(() => {
    const trigger = getTrigger();
    const targets = getTargets().filter((el): el is Element => el != null);
    if (!trigger || targets.length === 0) return;

    const mm = gsap.matchMedia();

    mm.add(
      {
        reduceMotion: '(prefers-reduced-motion: reduce)',
        allowMotion: '(prefers-reduced-motion: no-preference)',
      },
      (context) => {
        const { reduceMotion } = context.conditions as {
          reduceMotion: boolean;
          allowMotion: boolean;
        };

        if (reduceMotion) return;

        const tween = gsap.from(targets, {
          autoAlpha: 0,
          y: 24,
          duration: 0.36,
          stagger,
          ease: 'power3.out',
          clearProps: 'transform,opacity,visibility',
          scrollTrigger: {
            trigger,
            start,
            once: true,
          },
        });

        return () => {
          tween.scrollTrigger?.kill();
          tween.kill();
        };
      },
    );

    return () => {
      mm.revert();
    };
  }, deps);
}
