import { PROOF_BAR_ITEMS } from '../../content/site';
import styles from './proof-bar.module.css';

export function ProofBar() {
  return (
    <section className={styles.proofBar} aria-label="nightshift by the numbers">
      <div className={`ns-container ${styles.row}`}>
        {PROOF_BAR_ITEMS.map((item, i) => (
          <span key={item} className={styles.item}>
            {i > 0 && (
              <span className={styles.separator} aria-hidden="true">
                ·
              </span>
            )}
            {item}
          </span>
        ))}
      </div>
    </section>
  );
}

export default ProofBar;
