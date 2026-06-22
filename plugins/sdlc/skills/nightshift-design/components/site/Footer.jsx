import React from 'react';

/**
 * nightshift Footer — site footer with brand lockup, column nav,
 * and a quiet night-sky base. Columns passed as structured data.
 */
export function Footer({
  logoSrc = '../../assets/logomark.svg',
  tagline = 'Your AI software team that ships while you sleep.',
  columns = [],
  bottomNote = 'MIT © whimzyLive',
  builtOn = 'Built on Claude Code — agents, commands, skills, and hooks all the way down.',
  ...rest
}) {
  return (
    <footer
      style={{
        background: 'var(--bg-void)',
        borderTop: '1px solid var(--border-default)',
        padding: '56px 28px 28px',
        ...rest.style,
      }}
      {...rest}
    >
      <div style={{
        maxWidth: 'var(--container-max)', margin: '0 auto',
        display: 'flex', flexWrap: 'wrap', gap: 48, justifyContent: 'space-between',
      }}>
        <div style={{ maxWidth: 320 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
            <img src={logoSrc} width={26} height={26} alt="" />
            <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 16, color: 'var(--moon-100)' }}>
              night<span style={{ color: 'var(--accent)' }}>shift</span>
            </span>
          </div>
          <p style={{ fontFamily: 'var(--font-sans)', fontSize: 14, lineHeight: 1.6, color: 'var(--text-muted)', margin: 0 }}>{tagline}</p>
        </div>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 56 }}>
          {columns.map((col) => (
            <div key={col.title} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--text-dim)' }}>{col.title}</span>
              {col.items.map((it) => (
                <a key={it} href="#" style={{ fontFamily: 'var(--font-sans)', fontSize: 14, color: 'var(--text-muted)', textDecoration: 'none' }}
                  onMouseEnter={(e) => (e.currentTarget.style.color = 'var(--text-strong)')}
                  onMouseLeave={(e) => (e.currentTarget.style.color = 'var(--text-muted)')}
                >{it}</a>
              ))}
            </div>
          ))}
        </div>
      </div>

      <div style={{
        maxWidth: 'var(--container-max)', margin: '40px auto 0', paddingTop: 22,
        borderTop: '1px solid var(--border-soft)',
        display: 'flex', flexWrap: 'wrap', gap: 12, justifyContent: 'space-between', alignItems: 'center',
      }}>
        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--text-dim)' }}>{builtOn}</span>
        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--text-dim)' }}>{bottomNote}</span>
      </div>
    </footer>
  );
}
