'use client';

import { useRef } from 'react';

import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

import type { TerminalLine } from '../../lib/sections-content';
import { useIsomorphicLayoutEffect } from './use-isomorphic-layout-effect';
import styles from './terminal-window.module.css';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

export interface TerminalWindowProps {
  title?: string;
  lines: TerminalLine[];
}

// Streams a looping simulated `/auto` pipeline run — lines reveal
// sequentially, then loop (AC2). The one "alive" motion per the brand
// (nightshift-design references/patterns.md#streaming-terminal-motion).
export function TerminalWindow({
  title = 'zsh — nightshift',
  lines,
}: TerminalWindowProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const lineRefs = useRef<(HTMLDivElement | null)[]>([]);

  useIsomorphicLayoutEffect(() => {
    const root = rootRef.current;
    const lineEls = lineRefs.current.filter(
      (el): el is NonNullable<typeof el> => el != null,
    );
    if (!root || lineEls.length === 0) return;

    const mm = gsap.matchMedia();

    // Same reduceMotion/allowMotion pairing as the hero (NA-16): GSAP only
    // invokes the handler when at least one named condition matches, so a
    // default user (no explicit preference) needs `allowMotion` registered
    // too or the loop would never start.
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

        // Simplify: show the completed run, no streaming, no loop. A
        // no-op — lines are visible by default in CSS (nothing hid them),
        // so there's nothing to reset (matches the other sections' reveals).
        if (reduceMotion) return;

        // No `clearProps` here (unlike the section reveal hook): this
        // timeline loops forever (`repeat: -1`), so each line never
        // permanently settles the way a once-only reveal does, and no
        // `:hover` rule targets these lines — no stale-inline-style risk.
        const tl = gsap.timeline({
          repeat: -1,
          repeatDelay: 1.4,
          scrollTrigger: {
            trigger: root,
            start: 'top 85%',
            end: 'bottom top',
            toggleActions: 'play pause resume pause',
          },
        });

        lineEls.forEach((el, i) => {
          tl.from(
            el,
            { autoAlpha: 0, y: 8, duration: 0.36, ease: 'power3.out' },
            i === 0 ? 0 : '+=0.32',
          );
        });

        return () => {
          tl.scrollTrigger?.kill();
          tl.kill();
        };
      },
    );

    return () => {
      mm.revert();
    };
  }, [lines]);

  return (
    <div ref={rootRef} className={styles.window} data-testid="terminal-window">
      <div className={styles.titlebar}>
        <span className={styles.dots} aria-hidden="true">
          <span className={styles.dotRed} />
          <span className={styles.dotYellow} />
          <span className={styles.dotGreen} />
        </span>
        <span className={styles.title}>{title}</span>
      </div>
      <div className={styles.body}>
        {lines.map((line, i) => (
          <div
            key={`${line.agent ?? 'line'}-${i}`}
            ref={(el) => {
              lineRefs.current[i] = el;
            }}
            data-stage={line.agent}
            className={`${styles.line} ${line.tone ? styles[line.tone] : ''}`}
          >
            {line.prompt && (
              <span className={styles.prompt}>{line.prompt}</span>
            )}
            {line.text}
          </div>
        ))}
      </div>
    </div>
  );
}

export default TerminalWindow;
