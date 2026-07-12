import type { ReactNode } from 'react';

export type BadgeVariant =
  | 'neutral'
  | 'accent'
  | 'info'
  | 'success'
  | 'warning'
  | 'danger';

export interface BadgeProps {
  children: ReactNode;
  variant?: BadgeVariant;
  dot?: boolean;
  className?: string;
}

const VARIANT_STYLE: Record<
  BadgeVariant,
  { color: string; background: string; borderColor: string }
> = {
  neutral: {
    color: 'var(--text-muted)',
    background: 'rgba(255,255,255,0.05)',
    borderColor: 'var(--border-default)',
  },
  accent: {
    color: 'var(--terra-300)',
    background: 'var(--terra-tint)',
    borderColor: 'var(--border-accent)',
  },
  info: {
    color: 'var(--indigo-300)',
    background: 'var(--indigo-tint)',
    borderColor: 'rgba(124,147,240,0.4)',
  },
  success: {
    color: 'var(--green-400)',
    background: 'var(--green-tint)',
    borderColor: 'rgba(110,196,138,0.4)',
  },
  warning: {
    color: 'var(--amber-400)',
    background: 'var(--amber-tint)',
    borderColor: 'rgba(224,164,88,0.4)',
  },
  danger: {
    color: 'var(--red-400)',
    background: 'var(--red-tint)',
    borderColor: 'rgba(224,101,111,0.4)',
  },
};

/**
 * Sharp-cornered mono pill for nav/hero/footer metadata (`v0.4.0 · MIT`,
 * `a Claude Code plugin`). `border-radius: 0` intentionally overrides the
 * retained `--radius-pill` token (sharp-edges rule).
 */
export function Badge({
  children,
  variant = 'neutral',
  dot = false,
  className = '',
}: BadgeProps) {
  const tone = VARIANT_STYLE[variant];
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-none border font-mono text-xs font-medium tracking-[0.02em] whitespace-nowrap ${className}`}
      style={{
        padding: '4px 10px',
        color: tone.color,
        background: tone.background,
        borderColor: tone.borderColor,
      }}
    >
      {dot && (
        <span
          aria-hidden="true"
          className="inline-block size-1.5 flex-none rounded-full"
          style={{ background: 'currentColor' }}
        />
      )}
      {children}
    </span>
  );
}
