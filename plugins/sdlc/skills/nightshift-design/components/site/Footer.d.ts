import * as React from 'react';

export interface FooterColumn { title: string; items: string[]; }

export interface FooterProps {
  logoSrc?: string;
  tagline?: string;
  columns?: FooterColumn[];
  bottomNote?: string;
  builtOn?: string;
  style?: React.CSSProperties;
}

/** Site footer — brand lockup, column nav, quiet night-void base. */
export function Footer(props: FooterProps): JSX.Element;
