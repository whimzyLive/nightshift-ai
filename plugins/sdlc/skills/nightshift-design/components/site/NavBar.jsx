import React from 'react';

/**
 * nightshift NavBar — top navigation with logo lockup, links, GitHub stars,
 * and a primary CTA. Sticky, with a translucent night backdrop blur.
 */
export function NavBar({
  logoSrc = '../../assets/logomark.svg',
  brand = 'nightshift',
  links = [],
  stars = '1.2k',
  ctaLabel = 'Install',
  onCta,
  active,
  ...rest
}) {
  return (
    <header
      style={{
        position: 'sticky', top: 0, zIndex: 50,
        height: 'var(--nav-height)',
        display: 'flex', alignItems: 'center', gap: 28,
        padding: '0 28px',
        background: 'rgba(13,13,24,0.72)',
        borderBottom: '1px solid var(--border-default)',
        backdropFilter: 'blur(14px)',
        WebkitBackdropFilter: 'blur(14px)',
        ...rest.style,
      }}
      {...rest}
    >
      <a href="#" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
        <img src={logoSrc} width={28} height={28} alt="" />
        <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 17, letterSpacing: '-0.4px', color: 'var(--moon-100)' }}>
          night<span style={{ color: 'var(--accent)' }}>shift</span>
        </span>
      </a>

      <nav style={{ display: 'flex', alignItems: 'center', gap: 4, flex: 1 }}>
        {links.map((l) => (
          <a key={l.label} href={l.href || '#'}
            style={{
              fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 500,
              color: active === l.label ? 'var(--text-strong)' : 'var(--text-muted)',
              padding: '7px 12px', borderRadius: 'var(--radius-sm)',
              textDecoration: 'none', transition: 'color var(--dur-fast) var(--ease-out)',
            }}
            onMouseEnter={(e) => (e.currentTarget.style.color = 'var(--text-strong)')}
            onMouseLeave={(e) => (e.currentTarget.style.color = active === l.label ? 'var(--text-strong)' : 'var(--text-muted)')}
          >{l.label}</a>
        ))}
      </nav>

      <a href="#" style={{
        display: 'inline-flex', alignItems: 'center', gap: 8,
        fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-body)',
        border: '1px solid var(--border-default)', borderRadius: 'var(--radius-sm)',
        padding: '6px 12px', textDecoration: 'none',
      }}>
        <GitHubGlyph /> <span>{stars}</span>
      </a>

      <button onClick={onCta} style={{
        display: 'inline-flex', alignItems: 'center', height: 38, padding: '0 18px',
        background: 'var(--accent)', color: 'var(--text-on-accent)',
        border: 'none', borderRadius: 'var(--radius-md)',
        fontFamily: 'var(--font-sans)', fontSize: 14, fontWeight: 600, cursor: 'pointer',
        boxShadow: '0 6px 18px var(--terra-glow)',
      }}>{ctaLabel}</button>
    </header>
  );
}

function GitHubGlyph() {
  return (
    <svg width="15" height="15" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true" style={{ color: 'var(--text-muted)' }}>
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z"/>
    </svg>
  );
}
