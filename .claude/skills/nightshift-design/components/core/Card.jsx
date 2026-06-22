import React from 'react';

/**
 * nightshift Card — the base surface container.
 * `glow` lifts it with an accent ring (for featured/hero cards);
 * `interactive` adds hover elevation for clickable cards.
 */
export function Card({
  children,
  glow = false,
  interactive = false,
  padding = 24,
  as: Tag = 'div',
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  return (
    <Tag
      onMouseEnter={interactive ? () => setHover(true) : undefined}
      onMouseLeave={interactive ? () => setHover(false) : undefined}
      style={{
        background: 'var(--surface-card)',
        border: '1px solid',
        borderColor: glow ? 'var(--border-accent)' : (hover ? 'var(--border-strong)' : 'var(--border-default)'),
        borderRadius: 'var(--radius-lg)',
        padding,
        boxShadow: glow
          ? '0 0 0 1px var(--terra-glow), var(--elev-3)'
          : (interactive && hover ? 'var(--elev-3)' : 'var(--elev-1)'),
        transform: interactive && hover ? 'translateY(-2px)' : 'translateY(0)',
        transition: 'transform var(--dur-base) var(--ease-out), box-shadow var(--dur-base) var(--ease-out), border-color var(--dur-base) var(--ease-out)',
        cursor: interactive ? 'pointer' : 'default',
        ...style,
      }}
      {...rest}
    >
      {children}
    </Tag>
  );
}
