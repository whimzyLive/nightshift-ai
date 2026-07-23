'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { animate, motion, useMotionValue } from 'motion/react';

import { prefersReducedMotion } from './prefers-reduced-motion';
import { useInViewOnce } from './use-in-view-once';

// jsdom's HTMLMediaElement stub returns undefined from play(); a real browser
// returns a Promise that rejects when autoplay is blocked. Swallow both — a
// blocked play just leaves the poster in place.
function safePlay(el: HTMLVideoElement | null) {
  const p = el?.play();
  if (p && typeof p.catch === 'function') p.catch(() => undefined);
}

export type TerminalLineTone = 'default' | 'muted' | 'accent' | 'success';

export interface TerminalLine {
  /** Optional prompt glyph (e.g. '$') rendered before the text. */
  prompt?: string;
  /** Optional agent label rendered as a colored tag before the text. */
  agent?: string;
  /** Line body text. */
  text: string;
  /** Semantic color tone. Default: 'default'. */
  tone?: TerminalLineTone;
  /** Indent depth (each level = one step of left padding). Default: 0. */
  indent?: number;
}

export interface TerminalVideo {
  /** Playable source (e.g. an mp4 served from /public). */
  src: string;
  /** Poster frame shown before playback and under reduced motion. */
  poster?: string;
}

export interface TerminalProps {
  /** Chrome title-bar caption. */
  title: string;
  /** The scripted lines, revealed in order. Omit when `video` is set. */
  lines?: readonly TerminalLine[];
  /**
   * Render a looping muted video in the body instead of scripted lines. The
   * terminal chrome, magnetic tilt, idle drift, glow, and REPLAY control are
   * all preserved — REPLAY restarts the clip. Autoplays muted unless
   * `prefers-reduced-motion`, where it rests on the poster with native
   * controls.
   */
  video?: TerminalVideo;
  /**
   * Min height of the body — a px number, or any CSS length (e.g. a
   * `clamp(...)` string) to reserve space / scale with the viewport.
   */
  minHeight?: number | string;
  /**
   * Defer the scripted-line reveal until the terminal scrolls into view
   * (via the shared `useInViewOnce()` hook) instead of starting immediately
   * on mount. Default: false — every existing call site keeps its current
   * mount-reveal behaviour unchanged. Reduced motion (or an unsupported
   * `IntersectionObserver`) still renders every line immediately regardless
   * of this flag.
   */
  revealOnView?: boolean;
  className?: string;
}

const REVEAL_MS = 520; // --dur-terminal-line
const REVEAL_S = REVEAL_MS / 1000;
const CARET_BLINK_S = 0.5;
const INDENT_STEP_PX = 16;

// Shared chrome-bar control (REPLAY, FULL SCREEN) styling.
const CHROME_BTN =
  'flex-none rounded-none border border-[var(--border-default)] px-2 py-0.5 font-mono text-[11px] tracking-[0.04em] text-[var(--text-dim)] uppercase transition-colors duration-150 ease-out hover:border-[var(--link)] hover:text-[var(--text-strong)] focus-visible:outline-none focus-visible:shadow-[var(--glow-focus)] motion-reduce:transition-none';

const PlayIcon = (
  <svg
    viewBox="0 0 24 24"
    width="22"
    height="22"
    fill="currentColor"
    aria-hidden="true"
  >
    <path d="M8 5v14l11-7z" />
  </svg>
);
const PauseIcon = (
  <svg
    viewBox="0 0 24 24"
    width="22"
    height="22"
    fill="currentColor"
    aria-hidden="true"
  >
    <path d="M6 5h4v14H6zM14 5h4v14h-4z" />
  </svg>
);

const TONE_COLOR: Record<TerminalLineTone, string> = {
  default: 'var(--text-body)',
  muted: 'var(--text-dim)',
  accent: 'var(--accent)',
  success: 'var(--success)',
};

/**
 * Faux terminal that plays a scripted line-by-line run on loop, with a
 * magnetic pointer tilt and a slow ambient idle drift — all driven by Motion.
 * Deterministic server frame renders line 1 only, matching the
 * `night-sky.tsx` hydration pattern. Everything is skipped under
 * `prefers-reduced-motion` (the full run renders immediately, no tilt/drift).
 */
export function Terminal({
  title,
  lines = [],
  video,
  minHeight = 360,
  revealOnView = false,
  className = '',
}: TerminalProps) {
  const [visibleCount, setVisibleCount] = useState(1);
  const [hovering, setHovering] = useState(false);
  const [replayNonce, setReplayNonce] = useState(0);
  const [reduced, setReduced] = useState(false);
  const [fullscreen, setFullscreen] = useState(false);
  const [playing, setPlaying] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  // Only consulted when `revealOnView` is set — the reveal effect below is
  // otherwise indifferent to `inView`.
  const { ref: viewRef, inView } = useInViewOnce<HTMLDivElement>();
  const setWrapRefs = useCallback(
    (el: HTMLDivElement | null) => {
      wrapRef.current = el;
      viewRef.current = el;
    },
    [viewRef],
  );

  useEffect(() => setReduced(prefersReducedMotion()), []);

  // 3D transform driven by Motion values: tilt on hover, idle drift otherwise.
  const rotateX = useMotionValue(0);
  const rotateY = useMotionValue(0);
  const lift = useMotionValue(0);
  // Playback fraction (0–1) as a Motion value → the hover progress bar's
  // scaleX, so the bar tracks the clip every frame without re-rendering React.
  const progress = useMotionValue(0);

  // Reveal cadence + loop — a single Motion tween of a counter, looping.
  // Skipped entirely in video mode (the body is a <video>, not lines).
  useEffect(() => {
    if (video) return;
    if (prefersReducedMotion()) {
      setVisibleCount(lines.length);
      return;
    }
    // `revealOnView` defers the start until the terminal scrolls into view —
    // stays on the deterministic first-line frame until then.
    if (revealOnView && !inView) return;
    setVisibleCount(1);
    const total = lines.length;
    // Reveal once, then stop (no infinite loop — that kept burning frames).
    // onUpdate fires ~60/s; only push state when the revealed count changes,
    // so React re-renders ~once per line. `replayNonce` re-runs it on demand.
    let lastCount = 1;
    const controls = animate(0, total, {
      duration: total * REVEAL_S,
      ease: 'linear',
      onUpdate: (v) => {
        const next = Math.min(total, Math.max(1, Math.floor(v) + 1));
        if (next !== lastCount) {
          lastCount = next;
          setVisibleCount(next);
        }
      },
      onComplete: () => setVisibleCount(total),
    });
    return () => controls.stop();
  }, [lines.length, replayNonce, video, revealOnView, inView]);

  // Video mode: autoplay the muted loop unless reduced motion, where it rests
  // on its poster with native controls. `play()` may be blocked by the
  // browser's autoplay policy — the poster stays put, no error surfaces.
  useEffect(() => {
    if (!video || reduced) return;
    safePlay(videoRef.current);
  }, [video, reduced, replayNonce]);

  // Drive the progress bar from a rAF loop reading currentTime/duration. Only
  // the Motion value updates each frame — no React re-render.
  useEffect(() => {
    if (!video) return;
    let raf = 0;
    const tick = () => {
      const el = videoRef.current;
      if (el && el.duration > 0) progress.set(el.currentTime / el.duration);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [video, progress]);

  // Reflect native fullscreen state (Esc, browser UI, or the button) so the
  // clip shows native controls only while fullscreen.
  useEffect(() => {
    if (!video) return;
    const onChange = () =>
      setFullscreen(document.fullscreenElement === videoRef.current);
    document.addEventListener('fullscreenchange', onChange);
    return () => document.removeEventListener('fullscreenchange', onChange);
  }, [video]);

  // Mirror the element's play/pause state so the center toggle shows the right
  // icon regardless of how playback changed (button, native controls, replay).
  useEffect(() => {
    if (!video) return;
    const el = videoRef.current;
    if (!el) return;
    const sync = () => setPlaying(!el.paused);
    el.addEventListener('play', sync);
    el.addEventListener('pause', sync);
    sync();
    return () => {
      el.removeEventListener('play', sync);
      el.removeEventListener('pause', sync);
    };
  }, [video]);

  const togglePlay = () => {
    const el = videoRef.current;
    if (!el) return;
    if (el.paused) safePlay(el);
    else el.pause();
  };

  // REPLAY: restart the clip in video mode, re-run the reveal otherwise.
  const handleReplay = () => {
    if (video) {
      const el = videoRef.current;
      if (el) {
        el.currentTime = 0;
        safePlay(el);
      }
      return;
    }
    setReplayNonce((n) => n + 1);
  };

  // FULL SCREEN: request/exit native fullscreen on the video element
  // (webkitEnterFullscreen fallback for iOS Safari, which lacks the standard
  // Fullscreen API on non-video elements).
  const handleFullscreen = () => {
    const el = videoRef.current as
      | (HTMLVideoElement & { webkitEnterFullscreen?: () => void })
      | null;
    if (!el) return;
    if (document.fullscreenElement) {
      document.exitFullscreen?.();
      return;
    }
    if (el.requestFullscreen) el.requestFullscreen().catch(() => undefined);
    else el.webkitEnterFullscreen?.();
  };

  // Magnetic tilt on hover; idle drift when not hovered. Both operate on the
  // same Motion values and are mutually exclusive.
  useEffect(() => {
    if (prefersReducedMotion()) return;
    const el = wrapRef.current;
    if (!el) return;

    const onPointerMove = (event: PointerEvent) => {
      if (!hovering) return;
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;
      const px = (event.clientX - rect.left) / rect.width - 0.5;
      const py = (event.clientY - rect.top) / rect.height - 0.5;
      rotateX.set(-py * 8);
      rotateY.set(px * 10);
      lift.set(0);
    };
    const onPointerEnter = () => setHovering(true);
    const onPointerLeave = () => setHovering(false);

    el.addEventListener('pointermove', onPointerMove);
    el.addEventListener('pointerenter', onPointerEnter);
    el.addEventListener('pointerleave', onPointerLeave);
    return () => {
      el.removeEventListener('pointermove', onPointerMove);
      el.removeEventListener('pointerenter', onPointerEnter);
      el.removeEventListener('pointerleave', onPointerLeave);
    };
  }, [hovering, rotateX, rotateY, lift]);

  // Idle ambient drift — runs only while not hovered; Motion tweens revert
  // the values back to rest on hover / cleanup.
  useEffect(() => {
    if (prefersReducedMotion() || hovering) return;
    const dx = animate(rotateX, 0, { duration: 0.4, ease: 'easeOut' });
    const drift = animate(rotateY, [-1.4, 1.4], {
      duration: 3.6,
      ease: 'easeInOut',
      repeat: Infinity,
      repeatType: 'reverse',
    });
    const bob = animate(lift, [-4, 4], {
      duration: 5.2,
      ease: 'easeInOut',
      repeat: Infinity,
      repeatType: 'reverse',
    });
    return () => {
      dx.stop();
      drift.stop();
      bob.stop();
    };
  }, [hovering, rotateX, rotateY, lift]);

  const visible = lines.slice(0, visibleCount);
  const finalIndex = lines.length - 1;
  const fullyRevealed = visibleCount >= lines.length;

  return (
    <motion.div
      ref={setWrapRefs}
      className={`rounded-none border ${className}`}
      style={{
        rotateX,
        rotateY,
        y: lift,
        transformPerspective: 900,
        borderColor: 'var(--border-default)',
        background: 'var(--surface-terminal)',
        transformStyle: 'preserve-3d',
      }}
    >
      <p className="sr-only">
        Terminal preview: {'/auto PROJ-142'} runs the full delivery pipeline —
        reads the ticket, drafts the spec and plan, implements across
        specialized agents, passes the QA gate, and opens a reviewed pull
        request.
      </p>
      <div
        className="flex items-center gap-2 border-b px-3.5 py-2.5"
        style={{
          borderColor: 'var(--border-default)',
          background: 'rgba(255,255,255,0.03)',
        }}
      >
        <span aria-hidden="true" className="flex gap-1.5">
          <span
            className="size-2.5 rounded-full"
            style={{ background: 'var(--red-400)' }}
          />
          <span
            className="size-2.5 rounded-full"
            style={{ background: 'var(--amber-400)' }}
          />
          <span
            className="size-2.5 rounded-full"
            style={{ background: 'var(--green-400)' }}
          />
        </span>
        <span
          className="truncate font-mono text-xs"
          style={{ color: 'var(--text-dim)' }}
        >
          {title}
        </span>
        {(video || fullyRevealed) && (
          <span className="ml-auto flex items-center gap-1.5">
            {video && (
              <button
                type="button"
                onClick={handleFullscreen}
                aria-label="Play the video full screen"
                className={CHROME_BTN}
              >
                ⛶ full screen
              </button>
            )}
            <button
              type="button"
              onClick={handleReplay}
              aria-label="Replay the terminal run"
              className={CHROME_BTN}
            >
              ↺ replay
            </button>
          </span>
        )}
      </div>
      {video ? (
        // Outer box reserves `minHeight` and vertically centers the clip; the
        // inner wrapper hugs the 16:9 video so the overlay controls center on
        // the video itself, not the reserved space.
        <div
          className="flex items-center overflow-hidden"
          style={{ minHeight }}
        >
          <div className="relative w-full">
            <video
              ref={videoRef}
              aria-hidden="true"
              className="block w-full"
              style={{
                aspectRatio: '16 / 9',
                background: 'var(--surface-terminal)',
              }}
              src={video.src}
              poster={video.poster}
              muted
              loop
              playsInline
              preload="metadata"
              controls={reduced || fullscreen}
            />
            {/* Center play/pause toggle — fades in on hover. Hidden under
              reduced motion, where the native controls take over. */}
            {!reduced && (
              <button
                type="button"
                onClick={togglePlay}
                aria-label={playing ? 'Pause the video' : 'Play the video'}
                className="absolute top-1/2 left-1/2 flex size-14 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full text-white backdrop-blur-sm transition-opacity duration-200 ease-out focus-visible:outline-none focus-visible:shadow-[var(--glow-focus)]"
                style={{
                  opacity: hovering ? 1 : 0,
                  background: 'rgba(10,12,20,0.55)',
                  border: '1px solid rgba(255,255,255,0.25)',
                  paddingLeft: playing ? 0 : 3,
                }}
              >
                {playing ? PauseIcon : PlayIcon}
              </button>
            )}
            {/* Custom scrubber — pinned to the bottom edge, fades in on hover,
              keeping the chrome clean at rest. Click to seek. Hidden under
              reduced motion, where the native controls take over. */}
            {!reduced && (
              <div
                className="absolute inset-x-0 bottom-0 cursor-pointer px-3 pt-6 pb-3 transition-opacity duration-200 ease-out"
                style={{
                  opacity: hovering ? 1 : 0,
                  background:
                    'linear-gradient(to top, rgba(0,0,0,0.55), transparent)',
                }}
                onClick={(event) => {
                  const el = videoRef.current;
                  const track = event.currentTarget.querySelector(
                    '[data-track]',
                  ) as HTMLElement | null;
                  if (!el || !track || !(el.duration > 0)) return;
                  const rect = track.getBoundingClientRect();
                  const ratio = Math.min(
                    1,
                    Math.max(0, (event.clientX - rect.left) / rect.width),
                  );
                  el.currentTime = ratio * el.duration;
                  progress.set(ratio);
                }}
              >
                <div
                  data-track
                  className="h-1 w-full overflow-hidden rounded-full"
                  style={{ background: 'rgba(255,255,255,0.2)' }}
                >
                  <motion.div
                    className="h-full w-full origin-left rounded-full"
                    style={{ scaleX: progress, background: 'var(--accent)' }}
                  />
                </div>
              </div>
            )}
          </div>
        </div>
      ) : (
        <div
          aria-hidden="true"
          className="overflow-hidden px-4 py-4 font-mono text-sm leading-relaxed"
          style={{ minHeight }}
        >
          {visible.map((line, idx) => {
            const color = TONE_COLOR[line.tone ?? 'default'];
            const isCaret =
              idx === finalIndex && fullyRevealed && !prefersReducedMotion();
            return (
              <div
                key={idx}
                style={{ paddingLeft: (line.indent ?? 0) * INDENT_STEP_PX }}
              >
                {line.prompt && (
                  <span style={{ color: 'var(--code-prompt)', marginRight: 8 }}>
                    {line.prompt}
                  </span>
                )}
                {line.agent && <span style={{ color }}>{line.agent} </span>}
                <motion.span
                  style={{ color }}
                  animate={isCaret ? { opacity: [1, 0, 1] } : { opacity: 1 }}
                  transition={
                    isCaret
                      ? {
                          duration: CARET_BLINK_S * 2,
                          ease: 'linear',
                          repeat: Infinity,
                        }
                      : { duration: 0 }
                  }
                >
                  {line.text || ' '}
                </motion.span>
              </div>
            );
          })}
        </div>
      )}
    </motion.div>
  );
}
