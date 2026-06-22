import * as React from 'react';

export interface CardProps {
  children?: React.ReactNode;
  /** Accent ring + lift for featured cards. @default false */
  glow?: boolean;
  /** Hover elevation for clickable cards. @default false */
  interactive?: boolean;
  /** Inner padding in px. @default 24 */
  padding?: number;
  as?: keyof JSX.IntrinsicElements;
  style?: React.CSSProperties;
}

/** Base surface container on the night palette. */
export function Card(props: CardProps): JSX.Element;
