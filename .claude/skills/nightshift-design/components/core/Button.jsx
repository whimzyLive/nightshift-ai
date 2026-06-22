import React from 'react';

/**
 * nightshift Button — the primary action primitive.
 * Variants: primary (terracotta), secondary (surface), ghost (text), danger.
 * Monospace label option for terminal/command affordances.
 */
export function Button({
  children,
  variant = 'primary',
  size = 'md',
  mono = false,
  disabled = false,
  loading = false,
  iconLeft = null,
  iconRight = null,
  fullWidth = false,
  onClick,
  type = 'button',
  ...rest
}) {
  const sizes = {
    sm: { padding: '0 12px', height: 32, fontSize: 13, gap: 6, radius: 'var(--radius-sm)' },
    md: { padding: '0 18px', height: 40, fontSize: 14, gap: 8, radius: 'var(--radius-md)' },
    lg: { padding: '0 24px', height: 48, fontSize: 15, gap: 10, radius: 'var(--radius-md)' },
  };
  const s = sizes[size] || sizes.md;

  const variants = {
    primary: {
      background: 'var(--accent)',
      color: 'var(--text-on-accent)',
      border: '1px solid transparent',
      boxShadow: '0 1px 0 rgba(255,255,255,0.18) inset, 0 6px 18px var(--terra-glow)',
    },
    secondary: {
      background: 'var(--surface-raised)',
      color: 'var(--text-strong)',
      border: '1px solid var(--border-strong)',
      boxShadow: 'var(--elev-1)',
    },
    ghost: {
      background: 'transparent',
      color: 'var(--text-body)',
      border: '1px solid transparent',
      boxShadow: 'none',
    },
    danger: {
      background: 'transparent',
      color: 'var(--danger)',
      border: '1px solid var(--red-tint)',
      boxShadow: 'none',
    },
  };
  const v = variants[variant] || variants.primary;

  const [hover, setHover] = React.useState(false);
  const hoverStyle = !disabled && !loading && hover ? {
    primary: { background: 'var(--accent-hover)' },
    secondary: { background: 'var(--surface-overlay)', borderColor: 'var(--border-strong)' },
    ghost: { background: 'var(--surface-raised)', color: 'var(--text-strong)' },
    danger: { background: 'var(--red-tint)' },
  }[variant] : {};

  return (
    <button
      type={type}
      disabled={disabled || loading}
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        gap: s.gap, height: s.height, padding: s.padding, borderRadius: s.radius,
        fontFamily: mono ? 'var(--font-mono)' : 'var(--font-sans)',
        fontSize: s.fontSize, fontWeight: 600,
        letterSpacing: mono ? '0' : '-0.01em',
        width: fullWidth ? '100%' : 'auto',
        cursor: disabled || loading ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.45 : 1,
        transition: 'background var(--dur-fast) var(--ease-out), transform var(--dur-fast) var(--ease-out), color var(--dur-fast) var(--ease-out)',
        transform: !disabled && !loading && hover ? 'translateY(-1px)' : 'translateY(0)',
        whiteSpace: 'nowrap',
        ...v, ...hoverStyle,
      }}
      {...rest}
    >
      {loading && <Spinner />}
      {!loading && iconLeft}
      {children}
      {!loading && iconRight}
    </button>
  );
}

function Spinner() {
  return (
    <span
      style={{
        width: 14, height: 14, borderRadius: '50%',
        border: '2px solid currentColor', borderTopColor: 'transparent',
        display: 'inline-block', animation: 'ns-spin 0.7s linear infinite',
      }}
    >
      <style>{`@keyframes ns-spin{to{transform:rotate(360deg)}}`}</style>
    </span>
  );
}
