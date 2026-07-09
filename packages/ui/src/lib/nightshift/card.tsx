import type { ElementType, HTMLAttributes, ReactNode } from 'react';

import styles from './card.module.css';

export interface CardProps extends HTMLAttributes<HTMLElement> {
  children: ReactNode;
  /** Accent ring + lift — for featured/hero cards. @default false */
  glow?: boolean;
  /** Hover elevation for clickable cards. @default false */
  interactive?: boolean;
  /** Element tag to render. @default 'div' */
  as?: ElementType;
}

/**
 * nightshift Card — the base surface container. `--surface-card` fill,
 * hairline border (required on dark), deep soft shadow.
 */
export function Card({
  children,
  glow = false,
  interactive = false,
  as: Tag = 'div',
  className,
  ...rest
}: CardProps) {
  const classes = [
    styles.card,
    glow ? styles.glow : '',
    interactive ? styles.interactive : '',
    className ?? '',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <Tag className={classes} {...rest}>
      {children}
    </Tag>
  );
}

export default Card;
