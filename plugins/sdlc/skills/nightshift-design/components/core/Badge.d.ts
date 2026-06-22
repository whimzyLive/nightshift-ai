import * as React from 'react';

export interface BadgeProps {
  children?: React.ReactNode;
  /** Semantic tone. @default "neutral" */
  tone?: 'neutral' | 'accent' | 'info' | 'success' | 'warning' | 'danger';
  /** Leading status dot. @default false */
  dot?: boolean;
  /** Filled instead of tinted. @default false */
  solid?: boolean;
  /** Monospace label. @default true */
  mono?: boolean;
  /** @default "md" */
  size?: 'sm' | 'md';
}

/** Compact status / metadata pill. */
export function Badge(props: BadgeProps): JSX.Element;
