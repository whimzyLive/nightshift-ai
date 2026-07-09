import { Eyebrow } from '@nightshift-ai/ui';

import { FAQ_ITEMS } from '../../content/site';
import styles from './faq.module.css';

export function Faq() {
  return (
    <section id="faq" className={styles.section}>
      <div className={`ns-container ns-container--prose`}>
        <div className={styles.intro}>
          <Eyebrow>// Questions</Eyebrow>
          <h2 className={styles.header}>Questions builders ask first</h2>
        </div>

        <div className={styles.list}>
          {FAQ_ITEMS.map((item) => (
            <details key={item.q} className={styles.item}>
              <summary className={styles.question}>{item.q}</summary>
              <p className={styles.answer}>{item.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}

export default Faq;
