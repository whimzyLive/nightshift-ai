import * as React from 'react';

export interface NavLink { label: string; href?: string; }

export interface NavBarProps {
  logoSrc?: string;
  brand?: string;
  links?: NavLink[];
  /** GitHub star count to display. @default "1.2k" */
  stars?: string;
  ctaLabel?: string;
  onCta?: () => void;
  /** Label of the active link. */
  active?: string;
  style?: React.CSSProperties;
}

/** Sticky top navigation with translucent night backdrop blur. */
export function NavBar(props: NavBarProps): JSX.Element;
