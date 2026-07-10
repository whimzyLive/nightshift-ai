'use client';

import { useRef } from 'react';

import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

import { INSTALL_COMMANDS } from '../../lib/sections-content';
import { useIsomorphicLayoutEffect } from './use-isomorphic-layout-effect';
import { Eyebrow } from './eyebrow';
import styles from './install-section.module.css';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

// "install section" product section (AC1). Content reveals on scroll via
// ScrollTrigger, once per page view (AC3); the CTA button's hover lift +
// glow and the install snippets' hover accent border live in
// install-section.module.css (AC4).
export function InstallSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const revealRef = useRef<HTMLDivElement>(null);

  useIsomorphicLayoutEffect(() => {
    const section = sectionRef.current;
    const reveal = revealRef.current;
    if (!section || !reveal) return;

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
          gsap.set(reveal, { autoAlpha: 1, y: 0 });
          return;
        }

        // Brand motion budget: transform/opacity only, 120–360ms, one ease.
        const tween = gsap.from(reveal, {
          autoAlpha: 0,
          y: 24,
          duration: 0.36,
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
      <div ref={revealRef} className={styles.inner}>
        <Eyebrow>install in 60 seconds</Eyebrow>
        <h2 className={styles.heading}>Two lines in any Claude Code session</h2>
        <div className={styles.commands}>
          {INSTALL_COMMANDS.map((command) => (
            <div key={command} className={styles.snippet}>
              <span className={styles.prompt}>$</span>
              <span>{command}</span>
            </div>
          ))}
        </div>
        <p className={styles.note}>
          That&apos;s it. The shared workflow skills it depends on install
          automatically.
        </p>
        <a
          className={styles.cta}
          href="https://github.com/whimzyLive/nightshift-ai"
          target="_blank"
          rel="noreferrer"
        >
          View on GitHub
        </a>
      </div>
    </section>
  );
}

export default InstallSection;
