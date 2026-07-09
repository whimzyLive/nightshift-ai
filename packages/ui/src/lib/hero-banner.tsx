import styles from './hero-banner.module.css';

export interface HeroBannerProps {
  title: string;
  subtitle: string;
  ctaHref: string;
  ctaLabel: string;
}

export function HeroBanner({ title, subtitle, ctaHref, ctaLabel }: HeroBannerProps) {
  return (
    <section className={styles.hero}>
      <div className={styles.badge}>Nx + Next.js Starter</div>
      <h1 className={styles.title}>{title}</h1>
      <p className={styles.subtitle}>{subtitle}</p>
      <a href={ctaHref} target="_blank" rel="noreferrer" className={styles.cta}>
        {ctaLabel}
      </a>
    </section>
  );
}

export default HeroBanner;
