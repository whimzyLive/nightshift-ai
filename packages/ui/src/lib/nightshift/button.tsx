import type { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from 'react';

import styles from './button.module.css';

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
type ButtonSize = 'sm' | 'md' | 'lg';

interface ButtonOwnProps {
  children: ReactNode;
  /** @default 'primary' */
  variant?: ButtonVariant;
  /** @default 'md' */
  size?: ButtonSize;
  /** Monospace label — for command/terminal affordances. @default false */
  mono?: boolean;
  fullWidth?: boolean;
  iconLeft?: ReactNode;
  iconRight?: ReactNode;
  /** Renders an <a> instead of a <button> — for nav/anchor CTAs. */
  href?: string;
}

export type ButtonProps = ButtonOwnProps &
  Omit<ButtonHTMLAttributes<HTMLButtonElement>, keyof ButtonOwnProps> &
  Omit<AnchorHTMLAttributes<HTMLAnchorElement>, keyof ButtonOwnProps>;

/**
 * nightshift Button — the primary action primitive. Renders an <a> when
 * `href` is passed (nav/anchor CTAs), a <button> otherwise.
 */
export function Button({
  children,
  variant = 'primary',
  size = 'md',
  mono = false,
  fullWidth = false,
  iconLeft,
  iconRight,
  className,
  href,
  ...rest
}: ButtonProps) {
  const classes = [
    styles.btn,
    styles[`variant-${variant}`],
    styles[`size-${size}`],
    mono ? styles.mono : '',
    fullWidth ? styles.fullWidth : '',
    className ?? '',
  ]
    .filter(Boolean)
    .join(' ');

  if (href) {
    return (
      <a href={href} className={classes} {...rest}>
        {iconLeft}
        {children}
        {iconRight}
      </a>
    );
  }

  return (
    <button type="button" className={classes} {...rest}>
      {iconLeft}
      {children}
      {iconRight}
    </button>
  );
}

export default Button;
