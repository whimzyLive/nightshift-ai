import * as React from 'react';

export interface ButtonProps {
  children?: React.ReactNode;
  /** Visual style. @default "primary" */
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  /** @default "md" */
  size?: 'sm' | 'md' | 'lg';
  /** Use monospace label — for command/terminal affordances. @default false */
  mono?: boolean;
  disabled?: boolean;
  /** Show a spinner and block interaction. @default false */
  loading?: boolean;
  iconLeft?: React.ReactNode;
  iconRight?: React.ReactNode;
  fullWidth?: boolean;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  type?: 'button' | 'submit' | 'reset';
}

/**
 * Primary action primitive for nightshift.
 * @startingPoint section="Core" subtitle="Terracotta / surface / ghost / danger buttons" viewport="700x150"
 */
export function Button(props: ButtonProps): JSX.Element;
