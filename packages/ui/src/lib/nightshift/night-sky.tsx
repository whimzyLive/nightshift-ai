'use client';

import { useRef } from 'react';
import type { CSSProperties } from 'react';
import gsap from 'gsap';
import { useGSAP } from '@gsap/react';

export interface NightSkyProps {
  /**
   * `subpage` (default) is the calmer baseline (`--sky-opacity-subpage`);
   * `home` raises the starfield opacity to `--sky-opacity-home`. Both
   * variants get GSAP depth-parallax on mouse move and a tap-to-meteor
   * shower — both skipped under `prefers-reduced-motion`.
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

// Deterministic PRNG (constant seed) so the generated starfield is identical
// server-side and after hydration — no Math.random() at render time.
function mulberry32(seed: number): () => number {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function makeDots(
  count: number,
  seed: number,
  min: number,
  max: number,
  colors: string[],
): StarDot[] {
  const rnd = mulberry32(seed);
  const dots: StarDot[] = [];
  for (let i = 0; i < count; i++) {
    dots.push({
      x: Number((rnd() * 100).toFixed(2)),
      y: Number((rnd() * 100).toFixed(2)),
      s: Number((min + rnd() * (max - min)).toFixed(2)),
      c: colors[Math.floor(rnd() * colors.length)],
    });
  }
  return dots;
}

const WHITE = 'var(--star-white)';
const INDIGO = 'var(--star-indigo)';
const BRIGHT = 'var(--star-bright)';
const CYAN = 'var(--star-cyan)';

// Dense deterministic layers (~4× the original count) tiled at 360px.
const NEAR_DOTS = makeDots(54, 1337, 1.2, 2.0, [WHITE, WHITE, WHITE, INDIGO]);
const MID_DOTS = makeDots(30, 7331, 2.0, 2.8, [WHITE, WHITE, INDIGO]);
const FAR_DOTS = makeDots(16, 9157, 3.0, 3.9, [BRIGHT, CYAN, BRIGHT]);

const TILE = '360px 360px';

// Parallax depth per layer (px of travel at the screen edge). Foreground
// (near) shifts most; the far bright layer barely moves.
const NEAR_DEPTH = 34;
const MID_DEPTH = 20;
const FAR_DEPTH = 10;

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

const MAX_METEORS = 6;

/**
 * Shared starfield primitive — a fixed full-viewport background behind all
 * page content: a dense starfield with GSAP ambient drift/twinkle, mouse
 * depth-parallax (`quickTo` per layer), and a tap-spawned meteor shower
 * (`gsap.timeline`). All motion is set up inside `gsap.matchMedia` so it is
 * fully disabled — and reverted — under `prefers-reduced-motion`.
 */
export function NightSky({
  variant = 'subpage',
  className = '',
}: NightSkyProps) {
  const opacityClass =
    variant === 'home'
      ? 'opacity-[var(--sky-opacity-home)]'
      : 'opacity-[var(--sky-opacity-subpage)]';

  const nearRef = useRef<HTMLDivElement>(null);
  const midRef = useRef<HTMLDivElement>(null);
  const farRef = useRef<HTMLDivElement>(null);
  const nearInnerRef = useRef<HTMLDivElement>(null);
  const midInnerRef = useRef<HTMLDivElement>(null);
  const farInnerRef = useRef<HTMLDivElement>(null);
  const meteorLayerRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();

      mm.add('(prefers-reduced-motion: no-preference)', () => {
        // Ambient drift on the near layer's inner element (transform is free
        // on the inner; the outer wrapper owns the parallax transform).
        gsap.to(nearInnerRef.current, {
          x: -40,
          y: -40,
          duration: 120,
          ease: 'none',
          repeat: -1,
        });

        // Twinkle on the mid + far layers.
        gsap.to([midInnerRef.current, farInnerRef.current], {
          filter: 'brightness(1.6)',
          opacity: 1,
          duration: 1.7,
          ease: 'sine.inOut',
          repeat: -1,
          yoyo: true,
          stagger: 0.85,
        });

        // Depth parallax — one smoothed quickTo per axis per layer, driven by
        // mouse move. Foreground shifts most; far layer barely moves.
        const q = (el: HTMLDivElement | null, prop: 'x' | 'y') =>
          gsap.quickTo(el, prop, { duration: 0.6, ease: 'power3' });
        const setters: [ReturnType<typeof q>, ReturnType<typeof q>, number][] =
          [
            [q(nearRef.current, 'x'), q(nearRef.current, 'y'), NEAR_DEPTH],
            [q(midRef.current, 'x'), q(midRef.current, 'y'), MID_DEPTH],
            [q(farRef.current, 'x'), q(farRef.current, 'y'), FAR_DEPTH],
          ];

        function onMove(e: MouseEvent) {
          const dx = e.clientX / window.innerWidth - 0.5;
          const dy = e.clientY / window.innerHeight - 0.5;
          for (const [qx, qy, depth] of setters) {
            qx(-dx * depth);
            qy(-dy * depth);
          }
        }

        function onTap(e: PointerEvent) {
          const layer = meteorLayerRef.current;
          if (!layer || layer.childElementCount >= MAX_METEORS) return;

          const el = document.createElement('span');
          el.setAttribute('aria-hidden', 'true');
          Object.assign(el.style, {
            position: 'absolute',
            left: `${e.clientX}px`,
            top: `${e.clientY}px`,
            width: '160px',
            height: '2px',
            transformOrigin: '0 50%',
            pointerEvents: 'none',
            background:
              'linear-gradient(90deg, transparent, var(--star-white) 78%, var(--star-bright))',
            filter: 'drop-shadow(0 0 4px var(--star-bright))',
          } satisfies Partial<CSSStyleDeclaration>);
          layer.appendChild(el);

          const angle = 140 + Math.random() * 24; // 140–164° → down-left
          const travel = 300 + Math.random() * 160;
          const rad = (angle * Math.PI) / 180;

          gsap.set(el, { rotation: angle, autoAlpha: 0 });
          gsap
            .timeline({ onComplete: () => el.remove() })
            .to(el, { autoAlpha: 1, duration: 0.08 })
            .to(
              el,
              {
                x: Math.cos(rad) * travel,
                y: Math.sin(rad) * travel,
                duration: 0.72,
                ease: 'power2.in',
              },
              0,
            )
            .to(el, { autoAlpha: 0, duration: 0.3 }, '-=0.32');
        }

        window.addEventListener('mousemove', onMove);
        window.addEventListener('pointerdown', onTap);

        return () => {
          window.removeEventListener('mousemove', onMove);
          window.removeEventListener('pointerdown', onTap);
          if (meteorLayerRef.current) meteorLayerRef.current.replaceChildren();
        };
      });
    },
    { dependencies: [] },
  );

  return (
    <>
      <div
        aria-hidden="true"
        className={`pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-[var(--bg-void)] ${opacityClass} ${className}`}
      >
        <div ref={nearRef} className="absolute inset-0 will-change-transform">
          <div
            ref={nearInnerRef}
            className="absolute -inset-[12%]"
            style={{
              backgroundImage: layerBackground(NEAR_DOTS),
              backgroundRepeat: 'repeat',
              backgroundSize: TILE,
            }}
          />
        </div>
        <div ref={midRef} className="absolute inset-0 will-change-transform">
          <div
            ref={midInnerRef}
            className="absolute -inset-[12%]"
            style={{
              backgroundImage: layerBackground(MID_DOTS),
              backgroundRepeat: 'repeat',
              backgroundSize: TILE,
            }}
          />
        </div>
        <div ref={farRef} className="absolute inset-0 will-change-transform">
          <div
            ref={farInnerRef}
            className="absolute -inset-[12%]"
            style={{
              backgroundImage: layerBackground(FAR_DOTS),
              backgroundRepeat: 'repeat',
              backgroundSize: TILE,
            }}
          />
        </div>
        {HALOS.map((halo, i) => (
          <div
            key={i}
            className="absolute rounded-full blur-[10px]"
            style={halo.style}
          />
        ))}
      </div>

      <div
        ref={meteorLayerRef}
        aria-hidden="true"
        className="pointer-events-none fixed inset-0 -z-10 overflow-hidden"
      />
    </>
  );
}
