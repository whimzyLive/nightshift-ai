'use client';

import { useRef } from 'react';

import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

import type { Stat } from '../../lib/sections-content';
import { useIsomorphicLayoutEffect } from './use-isomorphic-layout-effect';
import styles from './stat-counter.module.css';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

// `id` is only a React list key upstream (how-it-works-section.tsx) — the
// component itself never reads it, so it's excluded from the props type.
export type StatCounterProps = Omit<Stat, 'id'>;

// Proof-number stats count up once when first scrolled into view (AC5).
export function StatCounter({ value, suffix = '', label }: StatCounterProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const numberRef = useRef<HTMLSpanElement>(null);

  useIsomorphicLayoutEffect(() => {
    const root = rootRef.current;
    const numberEl = numberRef.current;
    if (!root || !numberEl) return;

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

        if (reduceMotion) {
          numberEl.textContent = `${value}${suffix}`;
          return;
        }

        // Deliberately outside the brand's 120–360ms transform/opacity
        // budget: this tweens a numeric value (not transform/opacity), and
        // a count-up needs to read as counting rather than jumping. Same
        // `power3.out` ease as every other reveal on the page, though, so
        // it still feels like "one ease" system-wide.
        const counter = { val: 0 };
        const tween = gsap.to(counter, {
          val: value,
          duration: 1.2,
          ease: 'power3.out',
          onUpdate: () => {
            numberEl.textContent = `${Math.round(counter.val)}${suffix}`;
          },
          scrollTrigger: {
            trigger: root,
            start: 'top 85%',
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
  }, [value, suffix]);

  return (
    <div ref={rootRef} className={styles.stat} data-testid="stat-counter">
      <span ref={numberRef} className={styles.number}>
        {`0${suffix}`}
      </span>
      <span className={styles.label}>{label}</span>
    </div>
  );
}

export default StatCounter;
