import { Card, Eyebrow } from '@nightshift-ai/ui';

import { PROBLEM_SUBPOINTS } from '../../content/site';
import styles from './problem.module.css';

export function Problem() {
  return (
    <section className={styles.problem}>
      <div className="ns-container">
        <div className={styles.intro}>
          <Eyebrow>// The other 80%</Eyebrow>
          <h2 className={styles.header}>You don&apos;t lose time writing code. You lose it around the code.</h2>
          <p className={styles.body}>
            The AI already writes the code. What still eats the sprint is the{' '}
            <strong className={styles.strong}>connective tissue</strong>: turning a vague ticket
            into a real spec, a spec into a plan, keeping the plan honest while you implement, then
            reviewing the result without rubber-stamping your own work.
          </p>
          <p className={styles.body}>
            Coding assistants handle the middle 20%. The other 80% — the process — stays manual, or
            gets skipped on vibes and shipped unreviewed.
          </p>
        </div>

        <div className={styles.grid}>
          {PROBLEM_SUBPOINTS.map((point) => (
            <Card key={point.lead}>
              <p className={styles.lead}>{point.lead}</p>
              <p className={styles.subBody}>{point.body}</p>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}

export default Problem;
