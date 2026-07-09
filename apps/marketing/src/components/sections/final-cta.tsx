import { Button, InstallSnippet } from '@nightshift-ai/ui';

import { INSTALL_COMMANDS, REPO_URL } from '../../content/site';
import styles from './final-cta.module.css';

export function FinalCta() {
  return (
    <section className={styles.section}>
      <div className="ns-moon-glow" aria-hidden="true" />
      <div className={`ns-container ${styles.inner}`}>
        <h2 className={styles.header}>Put a ticket in tonight. Read a reviewed PR in the morning.</h2>
        <p className={styles.body}>
          Install takes about a minute. Point it at a ticket and watch the spec, plan, code, and
          review land — with the paper trail linked back where your team already works.
        </p>

        <div className={styles.installBlock}>
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
    </section>
  );
}

export default FinalCta;
