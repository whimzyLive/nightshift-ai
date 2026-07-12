import Link from 'next/link';
import type {
  AnchorHTMLAttributes,
  ButtonHTMLAttributes,
  ReactNode,
} from 'react';

interface CtaButtonSharedProps {
  children: ReactNode;
  className?: string;
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

// The neon-inverted CTA treatment — rest/hover/press states are pure CSS
// (:hover/:active) so this stays server-renderable, no client JS needed.
// Values are the `--btn-neon-*`/`--glow-neon*`/`--shadow-pop` tokens; see
// docs/design/marketing-site-handoff/tokens/{colors,spacing}.css.
const NEON_CLASSES =
  'inline-flex items-center justify-center gap-2 rounded-none border px-6 py-2.5 ' +
  'font-sans text-sm font-semibold no-underline whitespace-nowrap cursor-pointer ' +
  'bg-[var(--btn-neon-bg)] text-[var(--btn-neon-text)] border-[var(--btn-neon-border)] ' +
  'shadow-[var(--glow-neon)] ' +
  'transition-[background-color,color,border-color,box-shadow] duration-200 ease-out ' +
  'hover:bg-[var(--btn-neon-hover-bg)] hover:text-[var(--btn-neon-hover-text)] ' +
  'hover:border-[var(--btn-neon-hover-bg)] hover:shadow-[var(--glow-neon-hover),var(--shadow-pop)] ' +
  'active:bg-[var(--btn-neon-press-bg)] active:text-[var(--btn-neon-hover-text)] active:shadow-none ' +
  'focus-visible:outline-none focus-visible:shadow-[var(--glow-focus)] ' +
  'motion-reduce:transition-none';

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
  const { children, className = '', ...rest } = props;
  const classes = `${NEON_CLASSES} ${className}`;

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
