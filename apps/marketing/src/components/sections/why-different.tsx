import { Card, Eyebrow } from '@nightshift-ai/ui';

import { VALUE_CARDS } from '../../content/site';
import styles from './why-different.module.css';

export function WhyDifferent() {
  return (
    <section className={styles.section}>
      <div className="ns-container">
        <div className={styles.intro}>
          <Eyebrow>// Why builders choose it</Eyebrow>
          <h2 className={styles.header}>Why builders choose it</h2>
        </div>

        <div className={styles.grid}>
          {VALUE_CARDS.map((card) => (
            <Card key={card.header} interactive>
              <h3 className={styles.cardHeader}>{card.header}</h3>
              <p className={styles.cardBody}>{card.body}</p>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}

export default WhyDifferent;
