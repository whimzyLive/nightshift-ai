'use client';

import { useRef } from 'react';

import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

import {
  PIPELINE_IDEAS,
  PIPELINE_STAGES,
  STATS,
  TERMINAL_LINES,
} from '../../lib/sections-content';
import { useIsomorphicLayoutEffect } from './use-isomorphic-layout-effect';
import { Eyebrow } from './eyebrow';
import { IdeaCard } from './idea-card';
import { PipelineStageRow } from './pipeline-stage';
import { TerminalWindow } from './terminal-window';
import { StatCounter } from './stat-counter';
import styles from './how-it-works-section.module.css';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

// "how-it-works pipeline" product section (AC1): three idea cards, the
// connected pipeline stage strip, the streaming /auto terminal (AC2), and
// the proof-number stats (AC5). Section/card entrance reveals on scroll via
// GSAP ScrollTrigger, transform/opacity only, staggered, once per page view
// (AC3).
export function HowItWorksSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const cardRefs = useRef<(HTMLDivElement | null)[]>([]);
  const pipelineRef = useRef<HTMLDivElement>(null);

  useIsomorphicLayoutEffect(() => {
    const section = sectionRef.current;
    const cardEls = cardRefs.current.filter(
      (el): el is NonNullable<typeof el> => el != null,
    );
    const revealTargets = [...cardEls, pipelineRef.current].filter(
      (el): el is NonNullable<typeof el> => el != null,
    );
    if (!section || revealTargets.length === 0) return;

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
          gsap.set(revealTargets, { autoAlpha: 1, y: 0 });
          return;
        }

        // Brand motion budget: transform/opacity only, 120–360ms, one ease
        // (--dur-slow / power3.out, matching the hero's entrance timeline).
        const tween = gsap.from(revealTargets, {
          autoAlpha: 0,
          y: 24,
          duration: 0.36,
          stagger: 0.12,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: section,
            start: 'top 75%',
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
  }, []);

  return (
    <section ref={sectionRef} className={styles.section}>
      <div className={styles.inner}>
        <div className={styles.header}>
          <Eyebrow>how it works</Eyebrow>
          <h2 className={styles.heading}>
            Spec before plan, plan before code, review before merge
          </h2>
        </div>

        <div className={styles.cards}>
          {PIPELINE_IDEAS.map((idea, i) => (
            <IdeaCard
              key={idea.n}
              {...idea}
              ref={(el) => {
                cardRefs.current[i] = el;
              }}
            />
          ))}
        </div>

        <div ref={pipelineRef} className={styles.pipeline}>
          <PipelineStageRow stages={PIPELINE_STAGES} />
        </div>

        <div className={styles.terminalWrap}>
          <TerminalWindow
            title="zsh — nightshift · claude code"
            lines={TERMINAL_LINES}
          />
        </div>

        <div className={styles.stats}>
          {STATS.map((stat) => (
            <StatCounter key={stat.id} {...stat} />
          ))}
        </div>
      </div>
    </section>
  );
}

export default HowItWorksSection;
