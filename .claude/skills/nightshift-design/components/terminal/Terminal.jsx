import React from 'react';

/**
 * nightshift Terminal — a window frame with traffic lights + title bar,
 * and a dark body for terminal output. Pass `lines` for structured output
 * or arbitrary children. The signature surface of the brand.
 */
export function Terminal({
  title = 'zsh — nightshift',
  lines = null,
  children,
  showDot = true,
  minHeight,
  ...rest
}) {
  return (
    <div
      style={{
        background: 'var(--surface-terminal)',
        border: '1px solid var(--border-strong)',
        borderRadius: 'var(--radius-lg)',
        overflow: 'hidden',
        boxShadow: 'var(--elev-3)',
        fontFamily: 'var(--font-mono)',
        ...rest.style,
      }}
      {...rest}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          padding: '11px 14px',
          background:
            'linear-gradient(180deg, rgba(255,255,255,0.04), transparent)',
          borderBottom: '1px solid var(--border-default)',
        }}
      >
        {showDot && (
          <span style={{ display: 'flex', gap: 7 }}>
            <Dot c="#ff5f57" />
            <Dot c="#febc2e" />
            <Dot c="#28c840" />
          </span>
        )}
        <span
          style={{
            flex: 1,
            textAlign: 'center',
            fontSize: 12,
            color: 'var(--text-dim)',
            letterSpacing: '0.02em',
            marginRight: 46,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {title}
        </span>
      </div>
      <div
        style={{
          padding: '16px 18px',
          fontSize: 13,
          lineHeight: 1.75,
          minHeight,
          color: 'var(--moon-200)',
        }}
      >
        {lines
          ? lines.map((ln, i) => <TermLine key={i} {...normalize(ln)} />)
          : children}
      </div>
    </div>
  );
}

function Dot({ c }) {
  return (
    <span
      style={{
        width: 12,
        height: 12,
        borderRadius: '50%',
        background: c,
        display: 'inline-block',
      }}
    />
  );
}

function normalize(ln) {
  if (typeof ln === 'string') return { text: ln };
  return ln;
}

/**
 * A single terminal line. `tone` colors the glyph + text;
 * `prompt` renders a leading prompt; `agent` renders an agent name in accent.
 */
export function TermLine({
  text,
  tone = 'default',
  prompt,
  agent,
  indent = 0,
  dim = false,
}) {
  const tones = {
    default: 'var(--moon-200)',
    success: 'var(--success)',
    warning: 'var(--warning)',
    danger: 'var(--danger)',
    info: 'var(--info)',
    muted: 'var(--text-dim)',
    accent: 'var(--terra-400)',
  };
  return (
    <div
      style={{
        paddingLeft: indent * 18,
        color: dim ? 'var(--text-dim)' : tones[tone],
        whiteSpace: 'pre-wrap',
      }}
    >
      {prompt && (
        <span style={{ color: 'var(--code-prompt)', marginRight: 8 }}>
          {prompt}
        </span>
      )}
      {agent && <span style={{ color: 'var(--terra-400)' }}>{agent}</span>}
      {agent && text ? ' ' : ''}
      {text}
    </div>
  );
}
