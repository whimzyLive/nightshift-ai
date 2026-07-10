'use client';

import { useRef } from 'react';

import {
  PIPELINE_IDEAS,
  PIPELINE_STAGES,
  STATS,
  TERMINAL_LINES,
} from '../../lib/sections-content';
import { useScrollReveal } from './use-scroll-reveal';
import { Eyebrow } from './eyebrow';
import { IdeaCard } from './idea-card';
import { PipelineStageRow } from './pipeline-stage';
import { TerminalWindow } from './terminal-window';
import { StatCounter } from './stat-counter';
import styles from './how-it-works-section.module.css';

// "how-it-works pipeline" product section (AC1): three idea cards, the
// connected pipeline stage strip, the streaming /auto terminal (AC2), and
// the proof-number stats (AC5). Section/card entrance reveals on scroll via
// GSAP ScrollTrigger, transform/opacity only, staggered, once per page view
// (AC3).
export function HowItWorksSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const cardRefs = useRef<(HTMLDivElement | null)[]>([]);
  const pipelineRef = useRef<HTMLDivElement>(null);

  useScrollReveal(
    {
      getTrigger: () => sectionRef.current,
      getTargets: () => [...cardRefs.current, pipelineRef.current],
      stagger: 0.12,
    },
    [],
  );

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
          {STATS.map(({ id, ...stat }) => (
            <StatCounter key={id} {...stat} />
          ))}
        </div>
      </div>
    </section>
  );
}

export default HowItWorksSection;
