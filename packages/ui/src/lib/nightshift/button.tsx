import Link from 'next/link';
import type {
  AnchorHTMLAttributes,
  ButtonHTMLAttributes,
  ReactNode,
} from 'react';

export type CtaButtonSize = 'sm' | 'md' | 'lg';
export type CtaButtonVariant = 'primary' | 'secondary';

interface CtaButtonSharedProps {
  children: ReactNode;
  className?: string;
  /** @default 'md' */
  size?: CtaButtonSize;
  /** @default 'primary' */
  variant?: CtaButtonVariant;
}

type CtaButtonLinkProps = CtaButtonSharedProps &
  Omit<AnchorHTMLAttributes<HTMLAnchorElement>, 'className' | 'children'> & {
    href: string;
  };

type CtaButtonButtonProps = CtaButtonSharedProps &
  Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className' | 'children'> & {
    href?: undefined;
  };

export type CtaButtonProps = CtaButtonLinkProps | CtaButtonButtonProps;

// Layout/transition/focus — shared by every size + variant combination.
const BASE_CLASSES =
  'inline-flex items-center justify-center gap-2 rounded-none border ' +
  'font-sans font-semibold no-underline whitespace-nowrap cursor-pointer ' +
  'transition-[background-color,color,border-color,box-shadow] duration-200 ease-out ' +
  'focus-visible:outline-none focus-visible:shadow-[var(--glow-focus)] ' +
  'motion-reduce:transition-none';

const SIZE_CLASSES: Record<CtaButtonSize, string> = {
  md: 'px-6 py-2.5 text-sm',
  // ~34px height (design's in-terminal `approve ✓` / `run it again ↺` controls).
  sm: 'h-[34px] px-4 text-xs',
  // 48px height (design's Final CTA star button — nightshift-design Button's own lg spec).
  lg: 'h-12 px-6 text-[15px]',
};

// The neon-inverted CTA treatment (primary, unchanged) and the design's
// outline/muted secondary — rest/hover/press states are pure CSS (:hover/
// :active) so both stay server-renderable, no client JS needed. Values are
// token-backed only; see docs/design/marketing-site-handoff/tokens/colors.css.
const VARIANT_CLASSES: Record<CtaButtonVariant, string> = {
  primary:
    'bg-[var(--btn-neon-bg)] text-[var(--btn-neon-text)] border-[var(--btn-neon-border)] ' +
    'shadow-[var(--glow-neon)] ' +
    'hover:bg-[var(--btn-neon-hover-bg)] hover:text-[var(--btn-neon-hover-text)] ' +
    'hover:border-[var(--btn-neon-hover-bg)] hover:shadow-[var(--glow-neon-hover),var(--shadow-pop)] ' +
    'active:bg-[var(--btn-neon-press-bg)] active:text-[var(--btn-neon-hover-text)] active:shadow-none',
  secondary:
    'bg-transparent text-[var(--text-body)] border-[var(--border-strong)] shadow-none ' +
    'hover:bg-[var(--surface-raised)] hover:text-[var(--text-strong)] hover:border-[var(--border-strong)] ' +
    'hover:shadow-[var(--elev-1)] ' +
    'active:bg-[var(--surface-overlay)] active:shadow-none',
};

function isExternalHref(href: string): boolean {
  return (
    /^(https?:)?\/\//.test(href) ||
    href.startsWith('mailto:') ||
    href.startsWith('tel:')
  );
}

/**
 * Neon inverted CTA button. Polymorphic: pass `href` to render a link
 * (external hrefs get a plain `<a>`, internal ones a Next `<Link>`);
 * omit it to render a `<button>`.
 */
export function CtaButton(props: CtaButtonProps) {
  const {
    children,
    className = '',
    size = 'md',
    variant = 'primary',
    ...rest
  } = props;
  const classes = `${BASE_CLASSES} ${SIZE_CLASSES[size]} ${VARIANT_CLASSES[variant]} ${className}`;

  if (props.href) {
    const { href, ...anchorRest } = rest as Omit<
      CtaButtonLinkProps,
      'children' | 'className'
    >;
    if (isExternalHref(href)) {
      return (
        <a href={href} className={classes} {...anchorRest}>
          {children}
        </a>
      );
    }
    return (
      <Link href={href} className={classes} {...anchorRest}>
        {children}
      </Link>
    );
  }

  const { type = 'button', ...buttonRest } = rest as Omit<
    CtaButtonButtonProps,
    'children' | 'className' | 'href'
  >;
  return (
    <button type={type} className={classes} {...buttonRest}>
      {children}
    </button>
  );
}
