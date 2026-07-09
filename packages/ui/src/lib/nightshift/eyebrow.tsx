import type { ReactNode } from 'react';

import styles from './eyebrow.module.css';

export interface EyebrowProps {
  children: ReactNode;
}

/**
 * nightshift Eyebrow — the signature mono `// label` treatment above
 * section headings. Terracotta, uppercase, wide tracking.
 */
export function Eyebrow({ children }: EyebrowProps) {
  return <span className={styles.eyebrow}>{children}</span>;
}

export default Eyebrow;
