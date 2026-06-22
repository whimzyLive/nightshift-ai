import React from 'react';

/**
 * nightshift Pipeline — the spec→plan→impl→review→PR flow as connected blocks.
 * Each stage shows a command/label and an optional agent + status.
 * Renders horizontally on wide layouts, stacking with vertical connectors when narrow.
 */
export function Pipeline({ stages = [], orientation = 'horizontal', ...rest }) {
  const horizontal = orientation === 'horizontal';
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: horizontal ? 'row' : 'column',
        alignItems: horizontal ? 'stretch' : 'stretch',
        gap: 0,
        ...rest.style,
      }}
      {...rest}
    >
      {stages.map((st, i) => (
        <React.Fragment key={i}>
          <Stage {...st} horizontal={horizontal} />
          {i < stages.length - 1 && <Connector horizontal={horizontal} done={st.status === 'done'} />}
        </React.Fragment>
      ))}
    </div>
  );
}

function Stage({ command, label, agent, status = 'idle', horizontal }) {
  const states = {
    idle: { bd: 'var(--border-default)', cmd: 'var(--text-muted)', glow: 'none' },
    active: { bd: 'var(--border-accent)', cmd: 'var(--terra-400)', glow: 'var(--glow-accent)' },
    done: { bd: 'rgba(110,196,138,0.35)', cmd: 'var(--success)', glow: 'none' },
  };
  const s = states[status] || states.idle;
  return (
    <div style={{
      flex: 1, minWidth: horizontal ? 0 : undefined,
      background: 'var(--surface-card)',
      border: '1px solid', borderColor: s.bd,
      borderRadius: 'var(--radius-md)',
      padding: '14px 16px',
      boxShadow: s.glow,
      display: 'flex', flexDirection: 'column', gap: 6,
    }}>
      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13, fontWeight: 500, color: s.cmd }}>
        {status === 'done' ? '✓ ' : ''}{command}
      </span>
      {label && <span style={{ fontFamily: 'var(--font-sans)', fontSize: 13, color: 'var(--text-strong)' }}>{label}</span>}
      {agent && <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--text-dim)' }}>{agent}</span>}
    </div>
  );
}

function Connector({ horizontal, done }) {
  const color = done ? 'var(--success)' : 'var(--moon-500)';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: horizontal ? '0 6px' : '4px 0',
      color, fontFamily: 'var(--font-mono)', fontSize: 14, flex: 'none',
    }}>
      {horizontal ? '→' : '↓'}
    </div>
  );
}
