import React from 'react';

/**
 * nightshift Table — a quiet data table on the night palette.
 * Pass `columns` and `rows`; cells render strings or React nodes.
 * Hairline rows, mono headers, hover row highlight.
 */
export function Table({ columns = [], rows = [], dense = false, ...rest }) {
  const pad = dense ? '8px 12px' : '12px 16px';
  return (
    <div style={{
      border: '1px solid var(--border-default)',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      background: 'var(--surface-card)',
      ...rest.style,
    }} {...rest}>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontFamily: 'var(--font-sans)' }}>
        <thead>
          <tr style={{ background: 'rgba(255,255,255,0.02)' }}>
            {columns.map((c) => (
              <th key={c.key} style={{
                textAlign: c.align || 'left', padding: pad,
                fontFamily: 'var(--font-mono)', fontSize: 11, fontWeight: 500,
                letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--text-dim)',
                borderBottom: '1px solid var(--border-default)', whiteSpace: 'nowrap',
              }}>{c.header}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, ri) => (
            <Row key={ri} row={row} columns={columns} pad={pad} last={ri === rows.length - 1} />
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Row({ row, columns, pad, last }) {
  const [hover, setHover] = React.useState(false);
  return (
    <tr
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{ background: hover ? 'rgba(255,255,255,0.03)' : 'transparent', transition: 'background var(--dur-fast) var(--ease-out)' }}
    >
      {columns.map((c) => (
        <td key={c.key} style={{
          textAlign: c.align || 'left', padding: pad,
          fontSize: 14, color: c.muted ? 'var(--text-muted)' : 'var(--text-body)',
          fontFamily: c.mono ? 'var(--font-mono)' : 'var(--font-sans)',
          borderBottom: last ? 'none' : '1px solid var(--border-soft)',
        }}>{row[c.key]}</td>
      ))}
    </tr>
  );
}
