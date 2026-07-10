type ButtonProps = {
  variant?: 'primary' | 'secondary';
  href?: string;
  children: React.ReactNode;
} & React.ButtonHTMLAttributes<HTMLButtonElement>;

export function Button({
  variant = 'primary',
  href,
  children,
  className = '',
  ...props
}: ButtonProps) {
  const base =
    'inline-flex items-center justify-center rounded-md px-5 py-2.5 text-sm font-medium transition-colors';
  const styles =
    variant === 'primary'
      ? 'bg-accent text-strong hover:bg-accent-hover'
      : 'border border-strong text-body hover:bg-surface';
  const cls = `${base} ${styles} ${className}`;
  if (href)
    return (
      <a href={href} className={cls}>
        {children}
      </a>
    );
  return (
    <button className={cls} {...props}>
      {children}
    </button>
  );
}
