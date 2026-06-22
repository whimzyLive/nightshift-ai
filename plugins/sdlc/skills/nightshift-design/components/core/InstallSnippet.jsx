import React from 'react';

/**
 * nightshift InstallSnippet — a copy-to-clipboard command line.
 * The signature "install in 60 seconds" affordance. Renders a mono prompt,
 * the command, and a copy button that confirms inline.
 */
export function InstallSnippet({
  command = '/plugin install sdlc@nightshift',
  prompt = '$',
  label,
  ...rest
}) {
  const [copied, setCopied] = React.useState(false);
  const [hover, setHover] = React.useState(false);

  function copy() {
    try {
      navigator.clipboard?.writeText(command);
    } catch (e) { /* noop */ }
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }} {...rest}>
      {label && (
        <span style={{
          fontFamily: 'var(--font-mono)', fontSize: 12, letterSpacing: '0.14em',
          textTransform: 'uppercase', color: 'var(--text-dim)',
        }}>{label}</span>
      )}
      <div
        onMouseEnter={() => setHover(true)}
        onMouseLeave={() => setHover(false)}
        style={{
          display: 'flex', alignItems: 'center', gap: 14,
          background: 'var(--surface-terminal)',
          border: '1px solid',
          borderColor: hover ? 'var(--border-accent)' : 'var(--border-strong)',
          borderRadius: 'var(--radius-md)',
          padding: '14px 14px 14px 18px',
          fontFamily: 'var(--font-mono)', fontSize: 14,
          transition: 'border-color var(--dur-base) var(--ease-out)',
        }}
      >
        <span style={{ color: 'var(--code-prompt)', userSelect: 'none' }}>{prompt}</span>
        <code style={{ color: 'var(--moon-100)', flex: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {command}
        </code>
        <button
          onClick={copy}
          aria-label="Copy command"
          style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            background: copied ? 'var(--green-tint)' : 'var(--surface-raised)',
            color: copied ? 'var(--success)' : 'var(--text-muted)',
            border: '1px solid',
            borderColor: copied ? 'rgba(110,196,138,0.4)' : 'var(--border-default)',
            borderRadius: 'var(--radius-sm)', padding: '6px 12px',
            fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 500,
            cursor: 'pointer', whiteSpace: 'nowrap',
            transition: 'all var(--dur-fast) var(--ease-out)',
          }}
        >
          {copied ? 'copied ✓' : 'copy'}
        </button>
      </div>
    </div>
  );
}
