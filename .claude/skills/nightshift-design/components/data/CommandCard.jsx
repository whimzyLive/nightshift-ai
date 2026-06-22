import React from 'react';

/**
 * nightshift CommandCard — a slash-command reference entry for the docs.
 * Shows the command, its argument signature, a one-line description, and
 * the agent(s) it dispatches.
 */
export function CommandCard({
  command,
  args,
  description,
  agents = [],
  output,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  return (
    <div
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        background: 'var(--surface-card)',
        border: '1px solid', borderColor: hover ? 'var(--border-accent)' : 'var(--border-default)',
        borderRadius: 'var(--radius-lg)',
        padding: 18,
        display: 'flex', flexDirection: 'column', gap: 10,
        transition: 'border-color var(--dur-base) var(--ease-out)',
        ...rest.style,
      }}
      {...rest}
    >
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
        <code style={{ fontFamily: 'var(--font-mono)', fontSize: 15, fontWeight: 700, color: 'var(--terra-400)' }}>{command}</code>
        {args && <code style={{ fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-dim)' }}>{args}</code>}
      </div>
      <p style={{ margin: 0, fontFamily: 'var(--font-sans)', fontSize: 14, lineHeight: 1.55, color: 'var(--text-body)' }}>{description}</p>
      {output && (
        <div style={{
          fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--text-muted)',
          background: 'var(--surface-terminal)', border: '1px solid var(--border-soft)',
          borderRadius: 'var(--radius-sm)', padding: '8px 10px', lineHeight: 1.6,
        }}>{output}</div>
      )}
      {agents.length > 0 && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 2 }}>
          {agents.map((a) => (
            <span key={a} style={{
              fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--text-muted)',
              border: '1px solid var(--border-default)', borderRadius: 'var(--radius-pill)',
              padding: '2px 9px',
            }}>{a}</span>
          ))}
        </div>
      )}
    </div>
  );
}
