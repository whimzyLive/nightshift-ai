import type { ElementType, HTMLAttributes, ReactNode } from 'react';

export interface CardProps
  extends Omit<HTMLAttributes<HTMLElement>, 'className'> {
  children: ReactNode;
  as?: ElementType;
  className?: string;
}

/**
 * Sharp-cornered surface with the brand hover-lift: border warms to accent,
 * translateY(-3px), soft glow. Pure CSS (:hover) so this stays
 * server-renderable. Reduced motion keeps the color/border change but
 * cancels the lift transform (global transition-duration guard in
 * `global.css` already makes any remaining change instant).
 */
export function Card({
  children,
  as: Tag = 'div',
  className = '',
  ...rest
}: CardProps) {
  return (
    <Tag
      className={
        'block rounded-none border p-6 ' +
        'bg-[var(--surface-card)] border-[var(--border-default)] shadow-[var(--elev-1)] ' +
        'transition-[transform,border-color,box-shadow] duration-200 ease-out ' +
        'hover:border-[var(--border-accent)] hover:shadow-[var(--glow-card-hover)] ' +
        'hover:[transform:var(--lift-card)] ' +
        'motion-reduce:hover:[transform:none] ' +
        className
      }
      {...rest}
    >
      {children}
    </Tag>
  );
}
