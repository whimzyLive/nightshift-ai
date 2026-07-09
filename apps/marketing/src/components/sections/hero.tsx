import { Button, InstallSnippet, Terminal } from '@nightshift-ai/ui';

import { INSTALL_COMMANDS, PIPELINE_CAPTION, REPO_URL } from '../../content/site';
import styles from './hero.module.css';

export function Hero() {
  return (
    <section className={styles.hero}>
      <div className="ns-starfield" aria-hidden="true" />
      <div className="ns-moon-glow" aria-hidden="true" />
      <div className={`ns-container ${styles.inner}`}>
        <div className={styles.copy}>
          <h1 className={styles.headline}>
            Your AI software team that <span className={styles.accent}>ships while you sleep</span>
          </h1>
          <p className={styles.subheadline}>
            A Claude Code plugin that turns one terminal into a full delivery team — product
            manager, architect, tech lead, engineers, and QA. It reads a Jira ticket and ships the
            spec, plan, code, and review.
          </p>

          <div id="install" className={styles.installBlock}>
            <InstallSnippet
              label="Install in 60 seconds"
              command={INSTALL_COMMANDS[0]}
              copyLabel="copy install command"
            />
            <InstallSnippet command={INSTALL_COMMANDS[1]} copyLabel="copy install command" />
          </div>

          <div className={styles.actions}>
            <Button href={REPO_URL} variant="secondary" size="lg" target="_blank" rel="noreferrer">
              Star nightshift on GitHub
            </Button>
          </div>
        </div>

        <div className={styles.visual}>
          <Terminal title="zsh — nightshift" minHeight={120}>
            <span className={styles.pipelineLine}>{PIPELINE_CAPTION}</span>
          </Terminal>
        </div>
      </div>
    </section>
  );
}

export default Hero;
