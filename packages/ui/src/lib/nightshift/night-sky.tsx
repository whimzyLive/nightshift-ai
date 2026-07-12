'use client';

import type { CSSProperties } from 'react';

export interface NightSkyProps {
  /**
   * `subpage` (default) is the calmer baseline shipped by this story
   * (`--sky-opacity-subpage`). `home` reserves the seam for the heavier
   * home-only scene (crescent moon, meteor showers, mouse parallax) added
   * in a later story — for now it only raises the opacity to
   * `--sky-opacity-home`; no extra motifs render yet.
   */
  variant?: 'subpage' | 'home';
  className?: string;
}

interface StarDot {
  x: number;
  y: number;
  s: number;
  c: string;
}

// Fixed (not Math.random()) dot layouts — deterministic so server-rendered
// and hydrated client markup match exactly (this is a client component,
// but the starfield itself doesn't need randomness at runtime).
const NEAR_DOTS: StarDot[] = [
  { x: 6, y: 12, s: 1.6, c: 'var(--star-white)' },
  { x: 18, y: 42, s: 1.8, c: 'var(--star-white)' },
  { x: 32, y: 8, s: 1.4, c: 'var(--star-white)' },
  { x: 47, y: 28, s: 1.7, c: 'var(--star-white)' },
  { x: 61, y: 15, s: 1.5, c: 'var(--star-white)' },
  { x: 74, y: 46, s: 1.9, c: 'var(--star-white)' },
  { x: 88, y: 22, s: 1.4, c: 'var(--star-white)' },
  { x: 12, y: 68, s: 1.6, c: 'var(--star-white)' },
  { x: 41, y: 78, s: 1.5, c: 'var(--star-white)' },
  { x: 69, y: 82, s: 1.8, c: 'var(--star-white)' },
  { x: 93, y: 64, s: 1.4, c: 'var(--star-white)' },
  { x: 25, y: 92, s: 1.6, c: 'var(--star-white)' },
];

const MID_DOTS: StarDot[] = [
  { x: 9, y: 30, s: 2.4, c: 'var(--star-white)' },
  { x: 28, y: 58, s: 2.6, c: 'var(--star-indigo)' },
  { x: 44, y: 14, s: 2.3, c: 'var(--star-white)' },
  { x: 58, y: 66, s: 2.5, c: 'var(--star-white)' },
  { x: 77, y: 34, s: 2.6, c: 'var(--star-indigo)' },
  { x: 90, y: 84, s: 2.4, c: 'var(--star-white)' },
  { x: 15, y: 88, s: 2.5, c: 'var(--star-white)' },
  { x: 63, y: 92, s: 2.3, c: 'var(--star-indigo)' },
];

const FAR_DOTS: StarDot[] = [
  { x: 20, y: 22, s: 3.6, c: 'var(--star-bright)' },
  { x: 52, y: 48, s: 3.4, c: 'var(--star-cyan)' },
  { x: 82, y: 12, s: 3.8, c: 'var(--star-bright)' },
  { x: 35, y: 74, s: 3.5, c: 'var(--star-bright)' },
  { x: 95, y: 56, s: 3.3, c: 'var(--star-cyan)' },
];

function layerBackground(dots: StarDot[]): string {
  return dots
    .map(
      (d) =>
        `radial-gradient(${d.s}px ${d.s}px at ${d.x}% ${d.y}%, ${d.c} 0, ${d.c} 42%, transparent 78%)`,
    )
    .join(', ');
}

const HALOS: { style: CSSProperties }[] = [
  {
    style: {
      top: '-8%',
      right: '-6%',
      width: 420,
      height: 420,
      background: 'radial-gradient(circle, var(--halo-terra), transparent 70%)',
    },
  },
  {
    style: {
      top: '28%',
      left: '-8%',
      width: 300,
      height: 300,
      background:
        'radial-gradient(circle, var(--halo-indigo), transparent 70%)',
    },
  },
  {
    style: {
      bottom: '4%',
      right: '18%',
      width: 220,
      height: 220,
      background: 'radial-gradient(circle, var(--halo-cyan), transparent 70%)',
    },
  },
];

/**
 * Shared starfield primitive — fixed full-viewport background behind all
 * page content. Static baseline + a slow ambient drift/twinkle (disabled
 * under `prefers-reduced-motion` by the global guard in `global.css`).
 * Home-only heavy motifs (moon, meteors, mouse parallax) are out of scope
 * here (see spec NA-30) — `variant="home"` only raises opacity for now.
 */
export function NightSky({
  variant = 'subpage',
  className = '',
}: NightSkyProps) {
  const opacityClass =
    variant === 'home'
      ? 'opacity-[var(--sky-opacity-home)]'
      : 'opacity-[var(--sky-opacity-subpage)]';

  return (
    <div
      aria-hidden="true"
      className={`pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-[var(--bg-void)] ${opacityClass} ${className}`}
    >
      <div
        className="absolute -inset-[12%] animate-[ns-drift_120s_linear_infinite]"
        style={{
          backgroundImage: layerBackground(NEAR_DOTS),
          backgroundRepeat: 'repeat',
          backgroundSize: '520px 520px',
        }}
      />
      <div
        className="absolute -inset-[12%] animate-[ns-twinkle_var(--dur-twinkle)_ease-in-out_infinite]"
        style={{
          backgroundImage: layerBackground(MID_DOTS),
          backgroundRepeat: 'repeat',
          backgroundSize: '520px 520px',
        }}
      />
      <div
        className="absolute -inset-[12%] animate-[ns-twinkle_var(--dur-twinkle)_ease-in-out_infinite]"
        style={{
          backgroundImage: layerBackground(FAR_DOTS),
          backgroundRepeat: 'repeat',
          backgroundSize: '520px 520px',
          animationDelay: '-1.7s',
        }}
      />
      {HALOS.map((halo, i) => (
        <div
          key={i}
          className="absolute rounded-full blur-[10px]"
          style={halo.style}
        />
      ))}
    </div>
  );
}
