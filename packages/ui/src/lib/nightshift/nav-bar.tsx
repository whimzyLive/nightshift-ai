import type { ReactNode } from 'react';

import styles from './nav-bar.module.css';

export interface NavLink {
  label: string;
  href: string;
}

export interface NavBarProps {
  /** Path to the moon-mark asset, relative to the consuming app's /public. */
  logoSrc: string;
  /** @default 'nightshift' */
  brand?: string;
  links: NavLink[];
  ctaLabel: string;
  ctaHref: string;
  /** Extra nav item rendered after the links (e.g. a GitHub link). */
  secondary?: ReactNode;
}

/**
 * nightshift NavBar — sticky top nav with logo lockup, links, and a primary
 * CTA. Translucent night backdrop + blur. Collapses to a native disclosure
 * menu below the `sm` breakpoint — no client JS required.
 */
export function NavBar({ logoSrc, brand = 'nightshift', links, ctaLabel, ctaHref, secondary }: NavBarProps) {
  return (
    <header className={styles.nav}>
      <a href="/" aria-label={brand} className={styles.brand}>
        <img src={logoSrc} width={28} height={28} alt="" />
        <span className={styles.brandName}>
          night<span className={styles.accent}>shift</span>
        </span>
      </a>

      <nav className={styles.links} aria-label="Primary">
        {links.map((link) => (
          <a key={link.label} href={link.href} className={styles.link}>
            {link.label}
          </a>
        ))}
      </nav>

      <div className={styles.actions}>
        {secondary}
        <a href={ctaHref} className={styles.cta}>
          {ctaLabel}
        </a>
      </div>

      <details className={styles.mobileMenu}>
        <summary className={styles.mobileToggle} aria-label="Open menu">
          <span className={styles.hamburger} aria-hidden="true" />
        </summary>
        <div className={styles.mobilePanel}>
          {links.map((link) => (
            <a key={link.label} href={link.href} className={styles.mobileLink}>
              {link.label}
            </a>
          ))}
          {secondary}
          <a href={ctaHref} className={styles.cta}>
            {ctaLabel}
          </a>
        </div>
      </details>
    </header>
  );
}

export default NavBar;
