'use client';

import { useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';

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

/**
 * One accordion row. `measuredHeight` is captured once from the answer's
 * real `scrollHeight` on mount (content is static server-rendered richText,
 * so it never changes size after that) — toggling open/closed then only
 * flips between `0` and that fixed pixel value, giving a real animated
 * max-height with no measure-during-transition jump. Until that effect
 * runs, an open row (the default open item, or any item once it's the SSR
 * output) falls back to `max-height: none` — so the initially-open item is
 * fully visible immediately on the server-rendered/pre-hydration markup,
 * not clipped to `0` while waiting for a client effect. The site-wide
 * `@media (prefers-reduced-motion: reduce)` guard in global.css already
 * zeroes every `transition-duration` `!important`, so this needs no extra
 * JS reduced-motion branch to satisfy AC4/AC5 (see NA-30 memory).
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

  const maxHeight = isOpen ? (measuredHeight ?? 'none') : 0;

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
      <div
        id={contentId}
        ref={contentRef}
        className="overflow-hidden transition-[max-height,opacity] duration-400 ease-out motion-reduce:transition-none"
        style={{
          maxHeight,
          opacity: isOpen ? 1 : 0,
        }}
      >
        <div
          style={{ padding: '0 40px 22px 44px' }}
          className="[&_p]:m-0 [&_p]:text-[17px] [&_p]:leading-[1.65] [&_p]:text-[var(--text-body)] [&_code]:text-[var(--terra-400)]"
        >
          {item.answer}
        </div>
      </div>
    </div>
  );
}
