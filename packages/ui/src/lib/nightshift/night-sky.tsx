'use client';

import { useEffect, useRef, useState } from 'react';
import type { CSSProperties } from 'react';
import {
  motion,
  useMotionValue,
  useReducedMotion,
  useSpring,
  useTransform,
} from 'motion/react';

export interface NightSkyProps {
  /**
   * `subpage` (default) is the calmer baseline (`--sky-opacity-subpage`);
   * `home` raises the starfield opacity to `--sky-opacity-home`. Both
   * variants get Motion depth-parallax on mouse move and a tap-to-meteor
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

// Clicks on (or inside) these never spawn a meteor — meteors are for the
// empty sky only.
const INTERACTIVE_SELECTOR =
  'a,button,[role="button"],input,textarea,select,summary,label';

const MAX_METEORS = 6;
const SPRING = { stiffness: 90, damping: 20, mass: 0.6 } as const;

interface Meteor {
  id: number;
  x: number;
  y: number;
  angle: number;
  travel: number;
}

/**
 * Shared starfield primitive — a fixed full-viewport background behind all
 * page content: a dense starfield with Motion ambient drift/twinkle, mouse
 * depth-parallax (spring-smoothed motion values per layer), and a tap-spawned
 * meteor shower. All motion is skipped under `prefers-reduced-motion`.
 */
export function NightSky({
  variant = 'subpage',
  className = '',
}: NightSkyProps) {
  const opacityClass =
    variant === 'home'
      ? 'opacity-[var(--sky-opacity-home)]'
      : 'opacity-[var(--sky-opacity-subpage)]';

  const prefersReduced = useReducedMotion();
  const animate = !prefersReduced;

  // Normalized pointer offset (-0.5..0.5), spring-smoothed, mapped per layer.
  const px = useMotionValue(0);
  const py = useMotionValue(0);
  const sx = useSpring(px, SPRING);
  const sy = useSpring(py, SPRING);
  const nearX = useTransform(sx, (v) => -v * NEAR_DEPTH);
  const nearY = useTransform(sy, (v) => -v * NEAR_DEPTH);
  const midX = useTransform(sx, (v) => -v * MID_DEPTH);
  const midY = useTransform(sy, (v) => -v * MID_DEPTH);
  const farX = useTransform(sx, (v) => -v * FAR_DEPTH);
  const farY = useTransform(sy, (v) => -v * FAR_DEPTH);

  const [meteors, setMeteors] = useState<Meteor[]>([]);
  const nextId = useRef(0);

  useEffect(() => {
    if (prefersReduced) return;

    function onMove(e: MouseEvent) {
      px.set(e.clientX / window.innerWidth - 0.5);
      py.set(e.clientY / window.innerHeight - 0.5);
    }

    function onTap(e: PointerEvent) {
      // Only fire on empty sky — never when clicking an interactive element.
      const target = e.target as Element | null;
      if (target?.closest?.(INTERACTIVE_SELECTOR)) return;
      setMeteors((cur) => {
        if (cur.length >= MAX_METEORS) return cur;
        const id = nextId.current++;
        return [
          ...cur,
          {
            id,
            x: e.clientX,
            y: e.clientY,
            angle: 28 + ((id * 5) % 10), // 28–37° → smooth down-right diagonal
            travel: 360 + ((id * 47) % 120), // 360–480px
          },
        ];
      });
    }

    window.addEventListener('mousemove', onMove);
    window.addEventListener('pointerdown', onTap);
    return () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('pointerdown', onTap);
    };
  }, [prefersReduced, px, py]);

  const drift = animate ? { x: [0, -40], y: [0, -40] } : undefined;
  const twinkle = animate
    ? {
        opacity: [0.85, 1, 0.85],
        filter: ['brightness(1)', 'brightness(1.6)', 'brightness(1)'],
      }
    : undefined;

  return (
    <>
      <div
        aria-hidden="true"
        className={`pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-[var(--bg-void)] ${opacityClass} ${className}`}
      >
        <motion.div className="absolute inset-0" style={{ x: nearX, y: nearY }}>
          <motion.div
            className="absolute -inset-[12%]"
            style={{
              backgroundImage: layerBackground(NEAR_DOTS),
              backgroundRepeat: 'repeat',
              backgroundSize: TILE,
            }}
            animate={drift}
            transition={{ duration: 120, ease: 'linear', repeat: Infinity }}
          />
        </motion.div>
        <motion.div className="absolute inset-0" style={{ x: midX, y: midY }}>
          <motion.div
            className="absolute -inset-[12%]"
            style={{
              backgroundImage: layerBackground(MID_DOTS),
              backgroundRepeat: 'repeat',
              backgroundSize: TILE,
            }}
            animate={twinkle}
            transition={{ duration: 3.4, ease: 'easeInOut', repeat: Infinity }}
          />
        </motion.div>
        <motion.div className="absolute inset-0" style={{ x: farX, y: farY }}>
          <motion.div
            className="absolute -inset-[12%]"
            style={{
              backgroundImage: layerBackground(FAR_DOTS),
              backgroundRepeat: 'repeat',
              backgroundSize: TILE,
            }}
            animate={twinkle}
            transition={{
              duration: 3.4,
              ease: 'easeInOut',
              repeat: Infinity,
              delay: 1.7,
            }}
          />
        </motion.div>
        {HALOS.map((halo, i) => (
          <div
            key={i}
            className="absolute rounded-full blur-[10px]"
            style={halo.style}
          />
        ))}

        {/* Crescent moon — the one solid celestial asset. The crescent is
            carved by an inset shadow (dark bite bottom-right) + an indigo rim;
            an outer glow lifts it off the void. Rides the mid parallax plane
            and drifts on a slow float. */}
        <motion.div className="absolute inset-0" style={{ x: midX, y: midY }}>
          <motion.div
            className="absolute rounded-full"
            style={{
              top: 178,
              left: '84%',
              width: 110,
              height: 110,
              background:
                'radial-gradient(circle at 40% 38%, #fffaf2, #efe8db 55%, #d3cabb 100%)',
              boxShadow:
                '0 0 52px 12px rgba(245,243,239,0.42), inset -30px -8px 0 -8px rgba(13,13,24,0.9), inset -20px 4px 26px -10px rgba(139,156,247,0.45)',
              filter: 'blur(0.5px)',
            }}
            animate={animate ? { y: [0, -22, 0] } : undefined}
            transition={{ duration: 20, ease: 'easeInOut', repeat: Infinity }}
          />
        </motion.div>
      </div>

      {meteors.length > 0 && (
        <div
          aria-hidden="true"
          className="pointer-events-none fixed inset-0 -z-10 overflow-hidden"
        >
          {meteors.map((m) => {
            const rad = (m.angle * Math.PI) / 180;
            return (
              <motion.span
                key={m.id}
                className="absolute h-[2px] w-[230px] rounded-[2px]"
                style={{
                  left: m.x,
                  top: m.y,
                  transformOrigin: '0 50%',
                  rotate: m.angle,
                  background:
                    'linear-gradient(90deg, transparent, rgba(217,119,87,0.55) 58%, #ffffff)',
                  filter:
                    'drop-shadow(0 0 9px rgba(245,243,239,0.9)) drop-shadow(0 0 4px rgba(217,119,87,0.8))',
                }}
                initial={{ opacity: 0, x: 0, y: 0 }}
                animate={{
                  opacity: [0, 1, 1, 0],
                  x: Math.cos(rad) * m.travel,
                  y: Math.sin(rad) * m.travel,
                }}
                transition={{
                  duration: 1.15,
                  ease: 'linear',
                  times: [0, 0.15, 0.7, 1],
                }}
                onAnimationComplete={() =>
                  setMeteors((cur) => cur.filter((x) => x.id !== m.id))
                }
              />
            );
          })}
        </div>
      )}
    </>
  );
}
