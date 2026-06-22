import React from 'react';

/**
 * nightshift Badge / Pill — compact status & metadata label.
 * Tones map to the semantic palette; `dot` adds a status indicator,
 * `mono` (default) gives the terminal-texture label look.
 */
export function Badge({
  children,
  tone = 'neutral',
  dot = false,
  solid = false,
  mono = true,
  size = 'md',
  ...rest
}) {
  const tones = {
    neutral: { fg: 'var(--text-muted)', bg: 'rgba(255,255,255,0.05)', bd: 'var(--border-default)', dotc: 'var(--moon-400)' },
    accent:  { fg: 'var(--terra-300)', bg: 'var(--terra-tint)', bd: 'var(--border-accent)', dotc: 'var(--accent)' },
    info:    { fg: 'var(--indigo-300)', bg: 'var(--indigo-tint)', bd: 'rgba(124,147,240,0.4)', dotc: 'var(--indigo-400)' },
    success: { fg: 'var(--green-400)', bg: 'var(--green-tint)', bd: 'rgba(110,196,138,0.4)', dotc: 'var(--success)' },
    warning: { fg: 'var(--amber-400)', bg: 'var(--amber-tint)', bd: 'rgba(224,164,88,0.4)', dotc: 'var(--warning)' },
    danger:  { fg: 'var(--red-400)', bg: 'var(--red-tint)', bd: 'rgba(224,101,111,0.4)', dotc: 'var(--danger)' },
  };
  const t = tones[tone] || tones.neutral;
  const pad = size === 'sm' ? '2px 8px' : '4px 10px';
  const fs = size === 'sm' ? 11 : 12;

  const solidStyle = solid ? {
    background: t.dotc, color: 'var(--text-on-accent)', borderColor: 'transparent',
  } : {
    background: t.bg, color: t.fg, borderColor: t.bd,
  };

  return (
    <span
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 6,
        padding: pad, borderRadius: 'var(--radius-pill)',
        fontFamily: mono ? 'var(--font-mono)' : 'var(--font-sans)',
        fontSize: fs, fontWeight: 500, lineHeight: 1,
        letterSpacing: mono ? '0.02em' : '0',
        border: '1px solid', whiteSpace: 'nowrap',
        ...solidStyle,
      }}
      {...rest}
    >
      {dot && (
        <span style={{
          width: 6, height: 6, borderRadius: '50%',
          background: solid ? 'currentColor' : t.dotc, flex: 'none',
        }} />
      )}
      {children}
    </span>
  );
}
