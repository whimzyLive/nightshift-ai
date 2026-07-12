'use client';

import { useEffect, useRef, useState } from 'react';

import { animate, motion, useMotionValue } from 'motion/react';

// Verbatim from the design handoff (nightshift Landing.dc.html L190-195) —
// the duplicated-track phrase set. Two copies of the same line let the
// Motion `x` loop translate seamlessly from 0% to -50%.
const PHRASE_LINE =
  'you sleep, it ships ✦ spec before plan ✦ plan before code ✦ review before merge ✦ tests as the gate ✦ a team, not a megaprompt ✦ generic agents, per-repo config ✦ ';

// Matches the retired `--dur-marquee` token (34s).
const MARQUEE_DURATION_S = 34;

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
}

/**
 * Decorative looping mono ticker band — rendered twice on the home page,
 * once right under the header and once above the footer. Purely
 * illustrative — hidden from assistive tech. Solid terracotta band (`.ns-marquee`
 * in the design handoff) with near-white text (`--text-on-accent`) — the one
 * fully-saturated-accent band on the page. A single Motion `animate()` loop
 * on an `x` motion value drives the translate (0% → -50%, linear, infinite);
 * hovering pauses it in place via `AnimationPlaybackControls.pause()/.play()`
 * (matches the handoff's `.ns-marquee:hover .ns-marquee-track{animation-play-state:paused}`)
 * rather than toggling the declarative `animate` prop, which would restart
 * the keyframes from 0% instead of freezing mid-scroll. The deterministic
 * server/first-hydration frame renders static (matches the
 * `night-sky.tsx`/`terminal.tsx` pattern), then a direct `matchMedia` check
 * in an effect gates the loop off entirely under reduced motion — checked
 * directly rather than via Motion's `useReducedMotion` so specs that mock
 * `window.matchMedia` are honored (see NA-29 hard rules).
 */
export function PhraseMarquee() {
  const [reducedMotion, setReducedMotion] = useState(false);
  const x = useMotionValue('0%');
  const controlsRef = useRef<ReturnType<typeof animate> | null>(null);

  useEffect(() => {
    setReducedMotion(prefersReducedMotion());
  }, []);

  useEffect(() => {
    if (reducedMotion) return;
    const controls = animate(x, ['0%', '-50%'], {
      duration: MARQUEE_DURATION_S,
      ease: 'linear',
      repeat: Infinity,
    });
    controlsRef.current = controls;
    return () => controls.stop();
  }, [reducedMotion, x]);

  const pause = () => controlsRef.current?.pause();
  const resume = () => controlsRef.current?.play();

  return (
    <div
      aria-hidden="true"
      className="relative left-1/2 right-1/2 z-[1] -mx-[50vw] w-screen overflow-hidden border-t border-b"
      style={{
        background: 'var(--terra-500)',
        borderTopColor: 'var(--terra-400)',
        borderBottomColor: 'var(--terra-600)',
      }}
    >
      <motion.div
        className="flex w-max"
        style={{ x }}
        onHoverStart={pause}
        onHoverEnd={resume}
      >
        {[0, 1].map((copy) => (
          <span
            key={copy}
            className="font-mono whitespace-pre uppercase"
            style={{
              fontSize: 13,
              letterSpacing: '0.16em',
              color: 'var(--text-on-accent)',
              padding: '12px 0',
            }}
          >
            {PHRASE_LINE}
          </span>
        ))}
      </motion.div>
    </div>
  );
}
