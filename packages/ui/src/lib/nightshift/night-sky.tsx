'use client';

import { useEffect, useRef, useState } from 'react';
import type { CSSProperties } from 'react';
import {
  motion,
  useMotionValue,
  useReducedMotion,
  useScroll,
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

// Deterministic layers tiled at 360px (~half the earlier dense count).
const NEAR_DOTS = makeDots(30, 1337, 1.2, 2.0, [WHITE, WHITE, WHITE, INDIGO]);
const MID_DOTS = makeDots(20, 7331, 2.0, 2.8, [WHITE, WHITE, INDIGO]);
const FAR_DOTS = makeDots(10, 9157, 3.0, 3.9, [BRIGHT, CYAN, BRIGHT]);

const TILE = '360px 360px';

// Parallax depth per layer (px of travel at the screen edge). Foreground
// (near) shifts most; the far bright layer barely moves. Scaled up in step
// with the raised dot counts (30/20/10).
const NEAR_DEPTH = 38;
const MID_DEPTH = 27;
const FAR_DEPTH = 13;

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
// Ambient shooting-star cadence: check every ~4.2s, fire on ~45% of checks.
const AMBIENT_METEOR_MS = 4200;
const AMBIENT_METEOR_CHANCE = 0.55; // skip when Math.random() < this
const SPRING = { stiffness: 90, damping: 20, mass: 0.6 } as const;

// A1 — moon SETS on its own (right) side, fully exiting the fixed viewport-
// sized layer well before the page bottom (clamped via useTransform's
// default clamp — progress past the end of the range holds at the end
// value). Reduced motion binds directly to these end values.
const MOON_SET_RANGE: [number, number] = [0, 0.74];
const MOON_SET_Y_PX = 820;
const MOON_SET_X_PX = 50;
// A1 — dawn backdrop: ramps in from roughly the mid-page mark so it's
// already visible well before the FinalCta/footer band, not just in the
// final stretch.
const DAWN_RAMP_RANGE: [number, number] = [0.42, 0.85];
// A1 — sun rises on the opposite (left) side as the moon sets, resolving
// before the page bottom so the footer reads "moon gone, sun + clouds up".
const SUN_RISE_RANGE: [number, number] = [0.42, 0.8];
const SUN_RISE_Y_PX = 150;
// A1 — cloud drift: slow, small-amplitude horizontal wander, one duration
// per cloud so they don't move in lockstep.
const CLOUD_DRIFT_PX = 22;
const CLOUD_DRIFT_DURATIONS_S = [27, 33, 24];

// Easter egg: N rapid clicks on the same spot detonate a big bang there
// instead of a meteor.
const COMBO_THRESHOLD = 5;
const COMBO_SPOT_PX = 34; // "same spot" tolerance
const COMBO_WINDOW_MS = 1400; // max gap between combo clicks
// Deterministic radiating debris — fixed angles/distances so the render stays
// pure (no Math.random at render time).
// Debris uses viewport-relative reach (vmax) so it always flies clear off the
// edges of the screen from wherever the click landed.
const BIGBANG_PARTICLES = Array.from({ length: 34 }, (_, i) => {
  const angle = (i / 34) * Math.PI * 2 + (i % 2 ? 0.1 : 0);
  const reach = 110 + (i % 5) * 18; // vmax units
  return {
    dx: `${(Math.cos(angle) * reach).toFixed(1)}vmax`,
    dy: `${(Math.sin(angle) * reach).toFixed(1)}vmax`,
    size: 2 + (i % 3),
    color: i % 4 === 0 ? 'var(--star-bright)' : 'rgba(217,119,87,0.95)',
  };
});
const BIGBANG_RINGS = [0, 0.1, 0.22]; // stagger delays (s), post-blackout
// Blast starts only after the sky has snapped to black.
const BLACKOUT_S = 0.18;

// Crack phase — jagged fractures spread from the click point across the whole
// viewport while the page shudders. The blast expands in LOCKSTEP with the
// cracks (same duration + easing), so the light races out along the fractures
// and fills the screen exactly as they reach the edges — then it snaps black
// and the debris flies.
// Pacing multiplier for the whole detonation (cracks + blast stay in lockstep).
// Higher = slower; 1.7 ≈ 70% slower than the base timing.
const SLOWMO = 1.7;
const CRACK_S = 0.85 * SLOWMO;
// Connected cascade — each phase kicks off when the previous is ~20% in:
//   cracks (0) → explosion (20% of cracks) → debris + blackout (20% of explosion).
const EXPL_DELAY = CRACK_S * 0.2; // explosion ignites 20% into the crack draw
const DEBRIS_DELAY = EXPL_DELAY + CRACK_S * 0.25; // debris flings 20% into the blast
const BLACKOUT_DELAY = EXPL_DELAY + CRACK_S * 0.3; // black snaps with the debris
// Post-cracks blast durations, kept on the same slow-mo scale.
const BLACKOUT_DUR = 1.7 * SLOWMO;
const DEBRIS_DUR = 1.45 * SLOWMO;
const IMPACT_DUR = 0.45 * SLOWMO;
// The fractures' easing — shared by the flash + rings so they expand together.
const CRACK_EASE: [number, number, number, number] = [0.16, 1, 0.3, 1];

interface CrackStep {
  dist: number; // px from the origin along the crack direction
  perp: number; // px zig-zag offset perpendicular to that direction
}
interface Crack {
  angle: number;
  seg: CrackStep[];
}

// Deterministic fracture templates (no Math.random at render — angles/offsets
// derive from the index, so server and client agree).
function makeCrack(
  angle: number,
  steps: number,
  reach: number,
  seed: number,
): Crack {
  const seg: CrackStep[] = [];
  for (let s = 1; s <= steps; s++) {
    const dist = (reach * s) / steps;
    const perp = (s % 2 ? 1 : -1) * (14 + ((s * (seed + 3)) % 5) * 9);
    seg.push({ dist, perp });
  }
  return { angle, seg };
}
// Long primary fractures reaching off every edge, plus shorter secondary
// splinters near the impact for density.
const CRACK_MAINS: Crack[] = Array.from({ length: 11 }, (_, i) =>
  makeCrack(
    (i / 11) * Math.PI * 2 + (i % 2 ? 0.16 : -0.1),
    6,
    1500 + (i % 4) * 220,
    i,
  ),
);
const CRACK_BRANCHES: Crack[] = Array.from({ length: 9 }, (_, i) =>
  makeCrack((i / 9) * Math.PI * 2 + 0.3, 4, 620 + (i % 3) * 160, i + 5),
);
const CRACKS: Crack[] = [...CRACK_MAINS, ...CRACK_BRANCHES];

// Build the jagged SVG path for a crack originating at the click point.
function crackPath(x: number, y: number, c: Crack): string {
  const ux = Math.cos(c.angle);
  const uy = Math.sin(c.angle);
  const nx = -uy; // perpendicular unit vector
  const ny = ux;
  let d = `M ${x} ${y}`;
  for (const { dist, perp } of c.seg) {
    const gx = x + ux * dist + nx * perp;
    const gy = y + uy * dist + ny * perp;
    d += ` L ${gx.toFixed(1)} ${gy.toFixed(1)}`;
  }
  return d;
}

interface Meteor {
  id: number;
  x: number;
  y: number;
  angle: number;
  travel: number;
}

interface BigBang {
  id: number;
  x: number;
  y: number;
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

  // A1 — whole-document scroll progress drives the moon's set (outer
  // wrapper), the sun's rise, and the dawn backdrop's opacity, independently
  // of the moon's own pointer-parallax `x`/`y` (inner nodes, untouched) and
  // idle float.
  const { scrollYProgress } = useScroll();
  const scrollSetY = useTransform(scrollYProgress, MOON_SET_RANGE, [
    0,
    MOON_SET_Y_PX,
  ]);
  const scrollSetX = useTransform(scrollYProgress, MOON_SET_RANGE, [
    0,
    MOON_SET_X_PX,
  ]);
  const dawnOpacityFromScroll = useTransform(
    scrollYProgress,
    DAWN_RAMP_RANGE,
    [0, 1],
  );
  const sunRiseYFromScroll = useTransform(scrollYProgress, SUN_RISE_RANGE, [
    SUN_RISE_Y_PX,
    0,
  ]);
  const sunOpacityFromScroll = useTransform(
    scrollYProgress,
    SUN_RISE_RANGE,
    [0, 1],
  );
  const moonSetY = animate ? scrollSetY : MOON_SET_Y_PX;
  const moonSetX = animate ? scrollSetX : MOON_SET_X_PX;
  const dawnOpacity = animate ? dawnOpacityFromScroll : 1;
  const sunRiseY = animate ? sunRiseYFromScroll : 0;
  const sunOpacity = animate ? sunOpacityFromScroll : 1;

  const [meteors, setMeteors] = useState<Meteor[]>([]);
  const [bigBang, setBigBang] = useState<BigBang | null>(null);
  // Combo build-up level: 0 = idle, 3 or 4 = charging toward detonation. Drives
  // the escalating pre-blast shudder that merges into the crack shake at click 5.
  const [charge, setCharge] = useState(0);
  const nextId = useRef(0);
  const chargeTimer = useRef<number | null>(null);
  // Same-spot click combo tracker (position + timestamp + count).
  const comboRef = useRef<{ x: number; y: number; t: number; n: number }>({
    x: 0,
    y: 0,
    t: 0,
    n: 0,
  });

  useEffect(() => {
    if (prefersReduced) return;

    function onMove(e: MouseEvent) {
      px.set(e.clientX / window.innerWidth - 0.5);
      py.set(e.clientY / window.innerHeight - 0.5);
    }

    function spawnMeteor(x: number, y: number) {
      setMeteors((cur) => {
        if (cur.length >= MAX_METEORS) return cur;
        const id = nextId.current++;
        return [
          ...cur,
          {
            id,
            x,
            y,
            angle: 28 + ((id * 5) % 10), // 28–37° → smooth down-right diagonal
            travel: 360 + ((id * 47) % 120), // 360–480px
          },
        ];
      });
    }

    function onTap(e: PointerEvent) {
      // Only fire on empty sky — never when clicking an interactive element.
      const target = e.target as Element | null;
      if (target?.closest?.(INTERACTIVE_SELECTOR)) return;

      const x = e.clientX;
      const y = e.clientY;
      const t = e.timeStamp;
      const c = comboRef.current;
      const sameSpot =
        Math.hypot(x - c.x, y - c.y) <= COMBO_SPOT_PX &&
        t - c.t <= COMBO_WINDOW_MS;
      const n = sameSpot ? c.n + 1 : 1;
      comboRef.current = { x, y, t, n };

      if (chargeTimer.current != null) {
        window.clearTimeout(chargeTimer.current);
        chargeTimer.current = null;
      }

      if (n >= COMBO_THRESHOLD) {
        // Combo hit — swallow the meteor, clear the sky, and detonate. The
        // build-up shudder rolls straight into the crack shake.
        comboRef.current = { x: 0, y: 0, t: 0, n: 0 };
        setCharge(0);
        setMeteors([]);
        setBigBang({ id: nextId.current++, x, y });
        return;
      }

      if (n >= COMBO_THRESHOLD - 2) {
        // Two clicks out from detonation — start the escalating shudder, and
        // let it decay if the combo goes cold before the next click.
        setCharge(n);
        chargeTimer.current = window.setTimeout(
          () => setCharge(0),
          COMBO_WINDOW_MS,
        );
      } else {
        setCharge(0);
      }

      spawnMeteor(x, y);
    }

    // Ambient shooting stars — every ~4.2s there's a chance one streaks from
    // the upper-left, so the sky feels alive without any interaction. Paused
    // while the tab is hidden.
    const ambient = window.setInterval(() => {
      if (document.hidden || Math.random() < AMBIENT_METEOR_CHANCE) return;
      spawnMeteor(
        Math.random() * window.innerWidth * 0.7,
        Math.random() * window.innerHeight * 0.4,
      );
    }, AMBIENT_METEOR_MS);

    window.addEventListener('mousemove', onMove);
    window.addEventListener('pointerdown', onTap);
    return () => {
      window.clearInterval(ambient);
      if (chargeTimer.current != null) window.clearTimeout(chargeTimer.current);
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('pointerdown', onTap);
    };
  }, [prefersReduced, px, py]);

  // Merged crack-phase / build-up shudder — all on the starfield layer only
  // (scroll-safe: a `fixed` sibling of the blast, never its ancestor).
  //   • detonating → one heavy decaying shake across the crack draw
  //   • charging (3rd/4th combo click) → escalating jitter loop that rolls
  //     straight into the detonation shake
  let shudderAnimate: { x: number[] | number; y: number[] | number } = {
    x: 0,
    y: 0,
  };
  let shudderTransition: object = { duration: 0 };
  if (animate && bigBang) {
    // Amplitude envelope ramps up to a mid-shake peak then eases back down, so
    // the shudder starts and ends gently instead of jerking hard at t=0.
    shudderAnimate = {
      x: [0, -2, 4, -6, 6, -4.5, 3, -1, 0],
      y: [0, 1.5, -3, 4.5, -4.5, 3, -1.5, 0.5, 0],
    };
    shudderTransition = { duration: CRACK_S * 0.5, ease: 'easeInOut' };
  } else if (animate && charge >= COMBO_THRESHOLD - 2) {
    const a = charge >= COMBO_THRESHOLD - 1 ? 5.5 : 3; // heavier on the 4th click
    shudderAnimate = {
      x: [0, -a, a, -a * 0.6, a * 0.6, 0],
      y: [0, a * 0.7, -a * 0.7, a * 0.5, -a * 0.5, 0],
    };
    shudderTransition = {
      duration: charge >= COMBO_THRESHOLD - 1 ? 0.13 : 0.17,
      ease: 'easeInOut',
      repeat: Infinity,
    };
  }

  const drift = animate ? { x: [0, -40], y: [0, -40] } : undefined;
  // Opacity-only twinkle — animating `filter: brightness` here repainted the
  // whole tiled gradient layer every frame; opacity stays on the compositor.
  const twinkle = animate ? { opacity: [0.6, 1, 0.6] } : undefined;

  return (
    <>
      <motion.div
        aria-hidden="true"
        className={`pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-[var(--bg-void)] ${opacityClass} ${className}`}
        // Scroll-safe shudder: shakes ONLY this starfield layer. It's a `fixed`
        // sibling of the blast overlay, not an ancestor, so its transform can't
        // re-base the blast (the bug that killed the old body/html shake).
        animate={shudderAnimate}
        transition={shudderTransition}
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
            an outer glow lifts it off the void. A1: an outer wrapper carries
            the scroll-linked set X/Y; the existing inner node keeps its
            pointer-parallax x/y untouched — one axis can't carry both a
            scroll value and a pointer motion value, so the set composes via
            nesting instead. Rides the mid parallax plane and drifts on a
            slow float. */}
        <motion.div
          className="absolute inset-0"
          style={{ x: moonSetX, y: moonSetY }}
        >
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
        </motion.div>

        {variant === 'home' && (
          <>
            {/* Sun rises on the opposite (left) side as the moon sets — a
                soft, low-key terracotta glow disc (not a bright daytime
                sun), same accent hue as the crescent moon's indigo rim
                counterpart. */}
            <motion.div
              aria-hidden="true"
              data-testid="dawn-sun"
              className="absolute rounded-full"
              style={{
                bottom: 60,
                left: '10%',
                width: 130,
                height: 130,
                y: sunRiseY,
                opacity: sunOpacity,
                background:
                  'radial-gradient(circle at 45% 42%, var(--terra-300), var(--terra-500) 45%, var(--terra-glow) 72%, transparent 100%)',
                filter: 'blur(2px)',
              }}
            />
            {/* Faint cloud wisps drifting near the sun — barely-there
                atmosphere, warm-muted tint, restrained amplitude. */}
            {CLOUD_DRIFT_DURATIONS_S.map((duration, i) => (
              <motion.div
                key={i}
                aria-hidden="true"
                data-testid="dawn-cloud"
                className="absolute rounded-full"
                style={{
                  bottom: 96 + i * 44,
                  left: `${6 + i * 14}%`,
                  width: 170 - i * 20,
                  height: 38,
                  opacity: sunOpacity,
                  background: 'rgba(217,119,87,0.1)',
                  filter: 'blur(20px)',
                }}
                animate={animate ? { x: [0, CLOUD_DRIFT_PX, 0] } : undefined}
                transition={{ duration, ease: 'easeInOut', repeat: Infinity }}
              />
            ))}
          </>
        )}
      </motion.div>

      {variant === 'home' && (
        <motion.div
          aria-hidden="true"
          data-testid="dawn-backdrop"
          className="pointer-events-none fixed inset-0 -z-10"
          style={{
            opacity: dawnOpacity,
            // Same terracotta hue as --terra-glow/--terra-tint, at a richer
            // alpha so the pre-dawn wash actually reads against the page.
            background:
              'radial-gradient(circle at 50% 100%, rgba(217,119,87,0.42), rgba(217,119,87,0.2) 55%, transparent 85%)',
          }}
        />
      )}

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

      {bigBang && (
        <div
          key={bigBang.id}
          aria-hidden="true"
          className="pointer-events-none fixed inset-0 z-[9990] overflow-hidden"
        >
          {/* Crack phase — jagged fractures draw out from the click point
              across the whole viewport, over the still-live site, before the
              screen goes black. */}
          <svg
            className="absolute inset-0 h-full w-full"
            style={{ overflow: 'visible' }}
          >
            {CRACKS.map((c, i) => {
              const main = i < CRACK_MAINS.length;
              return (
                <motion.path
                  key={i}
                  d={crackPath(bigBang.x, bigBang.y, c)}
                  fill="none"
                  stroke="rgba(245,243,239,0.95)"
                  strokeWidth={main ? 2.6 : 1.5}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  style={{
                    filter:
                      'drop-shadow(0 0 3px rgba(217,119,87,0.9)) drop-shadow(0 0 7px rgba(245,243,239,0.45))',
                  }}
                  initial={{ pathLength: 0, opacity: 0 }}
                  animate={{ pathLength: 1, opacity: [0, 1, 1, 0] }}
                  transition={{
                    duration: CRACK_S,
                    ease: CRACK_EASE,
                    delay: (i % 5) * 0.02,
                    // Hold the fractures bright until they finish drawing
                    // (~CRACK_S), then snuff them out fast as the blast erupts
                    // from the same point — so nothing lingers once the black
                    // clears.
                    opacity: {
                      // Fully snuffed out by ~0.92·CRACK_S — before the black
                      // lands — so nothing lingers once it clears.
                      duration: CRACK_S,
                      times: [0, 0.05, 0.7, 0.92],
                    },
                  }}
                />
              );
            })}
          </svg>
          {/* Impact flash at the fracture origin. */}
          <motion.span
            className="absolute rounded-full"
            style={{
              left: bigBang.x,
              top: bigBang.y,
              width: 60,
              height: 60,
              marginLeft: -30,
              marginTop: -30,
              background:
                'radial-gradient(circle, #ffffff 0%, rgba(217,119,87,0.6) 45%, transparent 70%)',
              mixBlendMode: 'screen',
              willChange: 'transform, opacity',
            }}
            initial={{ scale: 0, opacity: 0.9 }}
            animate={{ scale: [0, 3, 5], opacity: [0.9, 0.5, 0] }}
            transition={{ duration: IMPACT_DUR, ease: 'easeOut' }}
          />
          {/* Blackout — the whole sky snaps to black after the cracks, then
              clears as debris flies out. Longest-lived → owns the cleanup. */}
          <motion.div
            className="absolute inset-0"
            style={{ background: '#000', willChange: 'opacity' }}
            initial={{ opacity: 0 }}
            animate={{ opacity: [0, 1, 1, 0] }}
            transition={{
              duration: BLACKOUT_DUR,
              ease: 'easeOut',
              times: [0, BLACKOUT_S / BLACKOUT_DUR, 0.45, 1],
              delay: BLACKOUT_DELAY,
            }}
            onAnimationComplete={() => setBigBang(null)}
          />
          {/* Core flash — erupts once the sky is black, filling the screen. */}
          <motion.span
            className="absolute rounded-full"
            style={{
              left: bigBang.x,
              top: bigBang.y,
              width: 80,
              height: 80,
              marginLeft: -40,
              marginTop: -40,
              background:
                'radial-gradient(circle, #ffffff 0%, var(--star-bright) 28%, rgba(217,119,87,0.7) 52%, transparent 72%)',
              mixBlendMode: 'screen',
              willChange: 'transform, opacity',
            }}
            initial={{ scale: 0, opacity: 0 }}
            // Blooms from the origin on the SAME curve + duration as the cracks
            // so the light fills the screen exactly as they reach the edges.
            animate={{ scale: [0, 42], opacity: [0, 1, 1, 0] }}
            transition={{
              duration: CRACK_S,
              ease: CRACK_EASE,
              delay: EXPL_DELAY,
              opacity: { duration: CRACK_S + 0.18, times: [0, 0.12, 0.72, 1] },
            }}
          />
          {/* Shockwave rings — expand clear across the viewport. */}
          {BIGBANG_RINGS.map((delay, i) => (
            <motion.span
              key={i}
              className="absolute rounded-full"
              style={{
                left: bigBang.x,
                top: bigBang.y,
                width: 40,
                height: 40,
                marginLeft: -20,
                marginTop: -20,
                border: '2px solid rgba(217,119,87,0.9)',
                boxShadow:
                  '0 0 22px rgba(217,119,87,0.7), inset 0 0 22px rgba(245,243,239,0.4)',
                mixBlendMode: 'screen',
                willChange: 'transform, opacity',
              }}
              initial={{ scale: 0, opacity: 0 }}
              animate={{ scale: [0, 90], opacity: [0.95, 0] }}
              transition={{
                duration: CRACK_S + 0.2,
                ease: CRACK_EASE,
                delay: EXPL_DELAY + delay * 0.4,
              }}
            />
          ))}
          {/* Radiating debris — flung off every edge. */}
          {BIGBANG_PARTICLES.map((p, i) => (
            <motion.span
              key={i}
              className="absolute rounded-full"
              style={{
                left: bigBang.x,
                top: bigBang.y,
                width: p.size,
                height: p.size,
                marginLeft: -p.size / 2,
                marginTop: -p.size / 2,
                background: p.color,
                boxShadow: '0 0 6px rgba(245,243,239,0.8)',
                mixBlendMode: 'screen',
                willChange: 'transform, opacity',
              }}
              initial={{ x: 0, y: 0, opacity: 0 }}
              animate={{
                x: p.dx,
                y: p.dy,
                opacity: [0, 1, 1, 0],
                scale: [1, 0.3],
              }}
              transition={{
                duration: DEBRIS_DUR,
                ease: 'easeOut',
                times: [0, 0.08, 0.75, 1],
                delay: DEBRIS_DELAY,
              }}
            />
          ))}
        </div>
      )}
    </>
  );
}
