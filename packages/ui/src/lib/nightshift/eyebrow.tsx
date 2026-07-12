import type { ReactNode } from 'react';

export interface EyebrowProps {
  children: ReactNode;
  className?: string;
}

/**
 * Mono section eyebrow — the brand's signature label treatment: uppercase,
 * terracotta, wide tracking, prefixed `//`. Wraps the `.ns-eyebrow` base
 * treatment declared in `global.css`.
 */
export function Eyebrow({ children, className = '' }: EyebrowProps) {
  return (
    <span
      className={`ns-eyebrow inline-flex items-center gap-1.5 ${className}`}
    >
      <span aria-hidden="true">{'//'}</span>
      {children}
    </span>
  );
}
