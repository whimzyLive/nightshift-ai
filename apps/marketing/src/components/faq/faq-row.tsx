'use client';

import { useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';

import { motion } from 'motion/react';

export interface FaqAccordionItem {
  id: number | string;
  question: string;
  /** Pre-rendered answer body (server-rendered richText — see faq-preview.tsx). */
  answer: ReactNode;
}

interface FaqRowProps {
  /** Q.NN display number, 1-based. Callers own the number they want shown —
   * this component only formats/pads it, it never derives or offsets it. */
  index: number;
  item: FaqAccordionItem;
  isOpen: boolean;
  isLast: boolean;
  onToggle: () => void;
}

function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;
}

// Matches the retired `--ease-out` token (cubic-bezier(.22,1,.36,1)); 400ms
// matches the retired `duration-400` Tailwind utility this replaces.
const EASE_OUT: [number, number, number, number] = [0.22, 1, 0.36, 1];
const DURATION_S = 0.4;

/**
 * One accordion row. `measuredHeight` is captured once from the answer's
 * real `scrollHeight` on mount (content is static server-rendered richText,
 * so it never changes size after that) — Motion then animates the row's
 * `height`/`opacity` between `0` and that fixed pixel value on every
 * toggle, giving a real animated height with no measure-during-transition
 * jump. Until that effect runs, an open row (the default open item, or any
 * item once it's the SSR output) falls back to `height: 'auto'` — so the
 * initially-open item is fully visible immediately on the server-rendered/
 * pre-hydration markup, not clipped to `0` while waiting for a client
 * effect. Reduced motion is gated with a direct `matchMedia` check (skips
 * the tween, snaps instantly) rather than relying on Motion's own reduced-
 * motion detection, matching the rest of this migration.
 *
 * The content wrapper keeps the `motion-reduce:transition-none` class name
 * even though the CSS transition it used to gate is now handled by Motion
 * — `home/faq-accordion.spec.tsx` (a different domain-agent's test file)
 * asserts on that class name, and this component's contract with its
 * consumers must not change.
 *
 * Shared by the home preview accordion (`home/faq-accordion.tsx`) and the
 * full FAQ page accordion (`faq/full-faq-accordion.tsx`) so the row visual
 * + animation contract cannot drift between the two (NA-38).
 */
export function FaqRow({ index, item, isOpen, isLast, onToggle }: FaqRowProps) {
  const contentRef = useRef<HTMLDivElement>(null);
  const [measuredHeight, setMeasuredHeight] = useState<number | null>(null);
  const contentId = `faq-answer-${item.id}`;

  useEffect(() => {
    if (contentRef.current) setMeasuredHeight(contentRef.current.scrollHeight);
  }, []);

  const reduced = prefersReducedMotion();
  const height = isOpen ? (measuredHeight ?? 'auto') : 0;

  return (
    <div
      style={{
        borderBottom: isLast ? 'none' : '1px solid var(--border-soft)',
      }}
    >
      <h3 style={{ margin: 0 }}>
        <button
          type="button"
          onClick={onToggle}
          aria-expanded={isOpen}
          aria-controls={contentId}
          className="flex w-full cursor-pointer items-center gap-3.5 text-left hover:opacity-85"
          style={{ padding: '22px 0', background: 'none', border: 'none' }}
        >
          <span
            aria-hidden="true"
            className="font-mono flex-none"
            style={{ fontSize: 14, color: 'var(--accent)' }}
          >
            {`Q.${String(index).padStart(2, '0')}`}
          </span>
          <span
            className="flex-1"
            style={{ fontSize: 18, color: 'var(--moon-100)' }}
          >
            {item.question}
          </span>
          <span
            aria-hidden="true"
            className="font-mono flex-none"
            style={{ fontSize: 20, color: 'var(--accent)' }}
          >
            {isOpen ? '−' : '+'}
          </span>
        </button>
      </h3>
      <motion.div
        id={contentId}
        ref={contentRef}
        className="overflow-hidden motion-reduce:transition-none"
        initial={false}
        animate={{ height, opacity: isOpen ? 1 : 0 }}
        transition={{ duration: reduced ? 0 : DURATION_S, ease: EASE_OUT }}
      >
        <div
          style={{ padding: '0 40px 22px 44px' }}
          className="[&_p]:m-0 [&_p]:text-[17px] [&_p]:leading-[1.65] [&_p]:text-[var(--text-body)] [&_code]:text-[var(--terra-400)]"
        >
          {item.answer}
        </div>
      </motion.div>
    </div>
  );
}
