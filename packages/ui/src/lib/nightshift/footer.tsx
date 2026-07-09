import styles from './footer.module.css';

export interface FooterColumn {
  title: string;
  items: { label: string; href: string }[];
}

export interface FooterProps {
  logoSrc: string;
  tagline: string;
  columns: FooterColumn[];
  bottomNote: string;
  builtOn: string;
}

/**
 * nightshift Footer — brand lockup + tagline left, column nav right, fine
 * print beneath. Sits on the deepest `--bg-void` (page floor).
 */
export function Footer({ logoSrc, tagline, columns, bottomNote, builtOn }: FooterProps) {
  return (
    <footer className={styles.footer}>
      <div className={styles.top}>
        <div className={styles.brandBlock}>
          <div className={styles.brand}>
            <img src={logoSrc} width={26} height={26} alt="" />
            <span className={styles.brandName}>
              night<span className={styles.accent}>shift</span>
            </span>
          </div>
          <p className={styles.tagline}>{tagline}</p>
        </div>

        <div className={styles.columns}>
          {columns.map((col) => (
            <div key={col.title} className={styles.column}>
              <span className={styles.columnTitle}>{col.title}</span>
              {col.items.map((item) => (
                <a key={item.label} href={item.href} className={styles.columnLink}>
                  {item.label}
                </a>
              ))}
            </div>
          ))}
        </div>
      </div>

      <div className={styles.bottom}>
        <span className={styles.fineprint}>{builtOn}</span>
        <span className={styles.fineprint}>{bottomNote}</span>
      </div>
    </footer>
  );
}

export default Footer;
