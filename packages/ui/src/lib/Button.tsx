type CommonProps = {
  variant?: 'primary' | 'secondary';
  children: React.ReactNode;
  className?: string;
};

type AnchorButtonProps = CommonProps &
  Omit<
    React.AnchorHTMLAttributes<HTMLAnchorElement>,
    'className' | 'children'
  > & {
    href: string;
  };

type NativeButtonProps = CommonProps &
  Omit<
    React.ButtonHTMLAttributes<HTMLButtonElement>,
    'className' | 'children'
  > & {
    href?: undefined;
  };

export type ButtonProps = AnchorButtonProps | NativeButtonProps;

export function Button(props: ButtonProps) {
  const {
    variant = 'primary',
    children,
    className = '',
    href,
    ...rest
  } = props;
  // radius-md, shadow-glow-accent, and the -1px hover lift mirror the
  // ns-btn-primary recipe (.claude/skills/nightshift-design/references/patterns.md)
  // — the button is the one deliberate "terracotta presence" per page.
  const base =
    'inline-flex items-center justify-center rounded-md px-5 py-2.5 text-sm font-semibold transition duration-200 ease-out';
  const styles =
    variant === 'primary'
      ? 'bg-accent text-on-accent shadow-glow-accent hover:bg-accent-hover hover:-translate-y-px active:bg-accent-press active:translate-y-0'
      : 'border border-line-strong text-body hover:border-accent hover:bg-surface hover:-translate-y-px';
  const cls = `${base} ${styles} ${className}`;

  if (href) {
    return (
      <a
        href={href}
        className={cls}
        {...(rest as React.AnchorHTMLAttributes<HTMLAnchorElement>)}
      >
        {children}
      </a>
    );
  }
  return (
    <button
      className={cls}
      {...(rest as React.ButtonHTMLAttributes<HTMLButtonElement>)}
    >
      {children}
    </button>
  );
}
