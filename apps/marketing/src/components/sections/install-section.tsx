'use client';

import { useRef } from 'react';

import { INSTALL_COMMANDS } from '../../lib/sections-content';
import { useScrollReveal } from './use-scroll-reveal';
import { Eyebrow } from './eyebrow';
import styles from './install-section.module.css';

// "install section" product section (AC1). Content reveals on scroll via
// ScrollTrigger, once per page view (AC3); the CTA button's hover lift +
// glow and the install snippets' hover accent border live in
// install-section.module.css (AC4).
export function InstallSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const revealRef = useRef<HTMLDivElement>(null);

  useScrollReveal(
    {
      getTrigger: () => sectionRef.current,
      getTargets: () => [revealRef.current],
    },
    [],
  );

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
