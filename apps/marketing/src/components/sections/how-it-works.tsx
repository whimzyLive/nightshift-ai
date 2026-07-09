import { Button, Eyebrow, Terminal } from '@nightshift-ai/ui';

import { AUTO_RUN_STEPS, REPO_URL } from '../../content/site';
import styles from './how-it-works.module.css';

export function HowItWorks() {
  return (
    <section id="how-it-works" className={styles.section}>
      <div className="ns-container">
        <div className={styles.intro}>
          <Eyebrow>// How it works</Eyebrow>
          <h2 className={styles.header}>One command runs the whole lifecycle</h2>
          <p className={styles.body}>
            Point it at a ticket. It triages the work, then runs each stage in order and closes
            the loop back to your tracker — spec before plan, plan before code, review before
            merge, tests as the gate.
          </p>
        </div>

        <Terminal title="zsh — nightshift" minHeight={48}>
          <span className={styles.command}>
            <span className={styles.prompt}>$</span> /auto PROJ-142
          </span>
        </Terminal>

        <table className={styles.table}>
          <caption className={styles.tableCaption}>The /auto run, step by step</caption>
          <thead>
            <tr>
              <th scope="col">Step</th>
              <th scope="col">What runs</th>
              <th scope="col">What you get</th>
            </tr>
          </thead>
          <tbody>
            {AUTO_RUN_STEPS.map((row) => (
              <tr key={row.step}>
                <td className={styles.stepCell}>{row.step}</td>
                <td className={styles.runsCell}>{row.runs}</td>
                <td>{row.get}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <p className={styles.note}>
          <strong className={styles.noteLead}>Fast path:</strong> small stories don&apos;t need the
          full ceremony. Stories at or under the lightweight threshold (default ≤3 points) skip
          straight to implementation.
        </p>
        <p className={styles.note}>
          <strong className={styles.noteLead}>Control:</strong> want to drive a single stage
          yourself? Every stage has its own verb: <code>/spec</code>, <code>/plan</code>,{' '}
          <code>/impl</code>, <code>/review</code>.
        </p>

        <Button href={REPO_URL} variant="ghost" mono target="_blank" rel="noreferrer">
          See the commands on GitHub
        </Button>
      </div>
    </section>
  );
}

export default HowItWorks;
