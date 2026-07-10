'use client';

import { useRef } from 'react';

import { TEAM } from '../../lib/sections-content';
import { useScrollReveal } from './use-scroll-reveal';
import { Eyebrow } from './eyebrow';
import { AgentCard } from './agent-card';
import styles from './team-section.module.css';

// "agent team grid" product section (AC1). Cards reveal on scroll via
// ScrollTrigger, staggered, once per page view (AC3); hover lift + accent
// border + glow is handled in agent-card.module.css (AC4).
export function TeamSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const cardRefs = useRef<(HTMLDivElement | null)[]>([]);

  useScrollReveal(
    {
      getTrigger: () => sectionRef.current,
      getTargets: () => cardRefs.current,
      stagger: 0.06,
    },
    [],
  );

  return (
    <section ref={sectionRef} className={styles.section}>
      <div className={styles.inner}>
        <div className={styles.header}>
          <Eyebrow>meet your team</Eyebrow>
          <h2 className={styles.heading}>Eleven specialists, one terminal</h2>
          <p className={styles.subhead}>
            Standby roles activate only when your project-context.md says your
            project has them.
          </p>
        </div>
        <div className={styles.grid}>
          {TEAM.map((agent, i) => (
            <AgentCard
              key={agent.name}
              {...agent}
              ref={(el) => {
                cardRefs.current[i] = el;
              }}
            />
          ))}
        </div>
      </div>
    </section>
  );
}

export default TeamSection;
