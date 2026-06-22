import React from 'react';

/**
 * nightshift AgentCard — a role in the AI software team.
 * Shows the agent's name (mono), what it owns, an avatar glyph (monogram),
 * and an optional status. Used in the "meet your team" grid.
 */
export function AgentCard({
  name,
  owns,
  glyph,
  tone = 'accent',
  status,
  standby = false,
  ...rest
}) {
  const tones = {
    accent: { ring: 'var(--terra-tint)', fg: 'var(--terra-400)', bd: 'rgba(217,119,87,0.3)' },
    info: { ring: 'var(--indigo-tint)', fg: 'var(--indigo-400)', bd: 'rgba(124,147,240,0.3)' },
    cyan: { ring: 'rgba(79,179,196,0.14)', fg: 'var(--cyan-400)', bd: 'rgba(79,179,196,0.3)' },
    green: { ring: 'var(--green-tint)', fg: 'var(--green-400)', bd: 'rgba(110,196,138,0.3)' },
  };
  const t = tones[tone] || tones.accent;
  const monogram = glyph || (name ? name.split('-').map((w) => w[0]).join('').slice(0, 2).toUpperCase() : '');

  const [hover, setHover] = React.useState(false);
  return (
    <div
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        display: 'flex', flexDirection: 'column', gap: 10,
        background: 'var(--surface-card)',
        border: '1px solid', borderColor: hover ? 'var(--border-strong)' : 'var(--border-default)',
        borderRadius: 'var(--radius-lg)',
        padding: 18,
        opacity: standby ? 0.66 : 1,
        boxShadow: hover ? 'var(--elev-2)' : 'var(--elev-1)',
        transform: hover ? 'translateY(-2px)' : 'translateY(0)',
        transition: 'all var(--dur-base) var(--ease-out)',
        ...rest.style,
      }}
      {...rest}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <span style={{
          width: 38, height: 38, flex: 'none', borderRadius: 'var(--radius-md)',
          background: t.ring, border: '1px solid', borderColor: t.bd,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: 'var(--font-mono)', fontSize: 14, fontWeight: 700, color: t.fg,
        }}>{monogram}</span>
        <span style={{ display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
          <span style={{ fontFamily: 'var(--font-mono)', fontSize: 14, fontWeight: 500, color: 'var(--moon-100)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{name}</span>
          {standby && <span style={{ fontFamily: 'var(--font-mono)', fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--text-dim)' }}>standby</span>}
        </span>
      </div>
      <p style={{ margin: 0, fontFamily: 'var(--font-sans)', fontSize: 13, lineHeight: 1.5, color: 'var(--text-muted)' }}>{owns}</p>
      {status && (
        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: t.fg }}>{status}</span>
      )}
    </div>
  );
}
