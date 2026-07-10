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
  const base =
    'inline-flex items-center justify-center rounded-md px-5 py-2.5 text-sm font-medium transition-colors';
  const styles =
    variant === 'primary'
      ? 'bg-accent text-on-accent hover:bg-accent-hover'
      : 'border border-strong text-body hover:bg-surface';
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
