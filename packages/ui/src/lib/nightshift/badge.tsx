import type { HTMLAttributes, ReactNode } from 'react';

import styles from './badge.module.css';

type BadgeTone = 'neutral' | 'accent' | 'info' | 'success' | 'warning' | 'danger';

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  children: ReactNode;
  /** @default 'neutral' */
  tone?: BadgeTone;
  /** Leading status dot. @default false */
  dot?: boolean;
  /** Filled vs tinted. @default false */
  solid?: boolean;
  /** Terminal-texture monospace label. @default true */
  mono?: boolean;
  /** @default 'md' */
  size?: 'sm' | 'md';
}

/**
 * nightshift Badge — status / metadata pill. Monospace by default (the
 * "terminal texture"). Used for agent state, ticket status, version tags.
 */
export function Badge({
  children,
  tone = 'neutral',
  dot = false,
  solid = false,
  mono = true,
  size = 'md',
  className,
  ...rest
}: BadgeProps) {
  const classes = [
    styles.badge,
    styles[`tone-${tone}`],
    solid ? styles.solid : '',
    mono ? styles.mono : '',
    styles[`size-${size}`],
    className ?? '',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <span className={classes} {...rest}>
      {dot && <span className={styles.dot} aria-hidden="true" />}
      {children}
    </span>
  );
}

export default Badge;
