import styles from './eyebrow.module.css';

export interface EyebrowProps {
  children: string;
}

// The signature mono `// LABEL` section marker (nightshift-design
// references/patterns.md — "Eyebrow (signature label)").
export function Eyebrow({ children }: EyebrowProps) {
  return <p className={styles.eyebrow}>{`// ${children}`}</p>;
}

export default Eyebrow;
