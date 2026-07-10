'use client';

import { useRef } from 'react';

import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

import { TEAM } from '../../lib/sections-content';
import { useIsomorphicLayoutEffect } from './use-isomorphic-layout-effect';
import { Eyebrow } from './eyebrow';
import { AgentCard } from './agent-card';
import styles from './team-section.module.css';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

// "agent team grid" product section (AC1). Cards reveal on scroll via
// ScrollTrigger, staggered, once per page view (AC3); hover lift + accent
// border + glow is handled in agent-card.module.css (AC4).
export function TeamSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const cardRefs = useRef<(HTMLDivElement | null)[]>([]);

  useIsomorphicLayoutEffect(() => {
    const section = sectionRef.current;
    const cardEls = cardRefs.current.filter(
      (el): el is NonNullable<typeof el> => el != null,
    );
    if (!section || cardEls.length === 0) return;

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
          gsap.set(cardEls, { autoAlpha: 1, y: 0 });
          return;
        }

        // Brand motion budget: transform/opacity only, 120–360ms, one ease.
        const tween = gsap.from(cardEls, {
          autoAlpha: 0,
          y: 24,
          duration: 0.36,
          stagger: 0.06,
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
