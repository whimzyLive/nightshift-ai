import React from 'react';

/**
 * nightshift CodeBlock — a syntax-tinted code surface with optional
 * filename header, line numbers, and a copy button. Tokens are passed as
 * structured spans so it stays framework-free (no highlighter dependency).
 */
export function CodeBlock({
  code = '',
  language = 'bash',
  filename,
  showLineNumbers = false,
  copyable = true,
  ...rest
}) {
  const [copied, setCopied] = React.useState(false);
  const lines = String(code).replace(/\n$/, '').split('\n');

  function copy() {
    try { navigator.clipboard?.writeText(code); } catch (e) { /* noop */ }
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  return (
    <div
      style={{
        background: 'var(--surface-terminal)',
        border: '1px solid var(--border-default)',
        borderRadius: 'var(--radius-md)',
        overflow: 'hidden',
        fontFamily: 'var(--font-mono)',
        ...rest.style,
      }}
      {...rest}
    >
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '9px 12px 9px 14px',
        borderBottom: '1px solid var(--border-soft)',
        background: 'rgba(255,255,255,0.02)',
      }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ fontSize: 12, color: 'var(--text-body)' }}>{filename || language}</span>
          {filename && <span style={{ fontSize: 11, color: 'var(--text-dim)' }}>{language}</span>}
        </span>
        {copyable && (
          <button
            onClick={copy}
            aria-label="Copy code"
            style={{
              background: 'transparent', border: 'none', cursor: 'pointer',
              color: copied ? 'var(--success)' : 'var(--text-dim)',
              fontFamily: 'var(--font-mono)', fontSize: 11, padding: '2px 6px',
            }}
          >{copied ? 'copied ✓' : 'copy'}</button>
        )}
      </div>
      <pre style={{ margin: 0, padding: '14px 16px', overflowX: 'auto', fontSize: 13, lineHeight: 1.7 }}>
        <code>
          {lines.map((ln, i) => (
            <div key={i} style={{ display: 'flex' }}>
              {showLineNumbers && (
                <span style={{ width: 28, flex: 'none', color: 'var(--moon-500)', userSelect: 'none', textAlign: 'right', marginRight: 16 }}>{i + 1}</span>
              )}
              <span style={{ color: 'var(--moon-200)', whiteSpace: 'pre' }}>{highlight(ln)}</span>
            </div>
          ))}
        </code>
      </pre>
    </div>
  );
}

/** Lightweight token tinting for shell / conventional-commit style lines. */
function highlight(line) {
  // Comments
  if (line.trimStart().startsWith('#')) {
    return <span style={{ color: 'var(--code-comment)' }}>{line}</span>;
  }
  const parts = [];
  let rest = line;
  // leading prompt
  const promptMatch = rest.match(/^(\s*)([$>])\s/);
  if (promptMatch) {
    parts.push(<span key="ind">{promptMatch[1]}</span>);
    parts.push(<span key="p" style={{ color: 'var(--code-prompt)' }}>{promptMatch[2]} </span>);
    rest = rest.slice(promptMatch[0].length);
  }
  // conventional-commit prefix
  const ccMatch = rest.match(/^(feat|fix|docs|chore|refactor|test|perf|build|ci|style)(\([^)]+\))?(!)?:/);
  if (ccMatch) {
    parts.push(<span key="cc" style={{ color: 'var(--code-fn)' }}>{ccMatch[1]}</span>);
    if (ccMatch[2]) parts.push(<span key="scope" style={{ color: 'var(--code-num)' }}>{ccMatch[2]}</span>);
    if (ccMatch[3]) parts.push(<span key="bang" style={{ color: 'var(--danger)' }}>!</span>);
    parts.push(<span key="colon" style={{ color: 'var(--code-punct)' }}>:</span>);
    rest = rest.slice(ccMatch[0].length);
  }
  parts.push(<span key="rest">{rest}</span>);
  return parts;
}
