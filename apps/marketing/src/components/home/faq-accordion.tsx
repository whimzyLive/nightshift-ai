'use client';

import { useState } from 'react';

import { FaqRow, type FaqAccordionItem } from '../faq/faq-row';

// Re-exported so downstream imports of `FaqAccordionItem` from this module
// keep working after the row was extracted to `faq/faq-row.tsx` (NA-38).
export type { FaqAccordionItem } from '../faq/faq-row';

/**
 * Top-5 FAQ preview accordion — solid card, one entry open at a time
 * (index 0 open by default, matching the design handoff's initial state).
 * The row itself (`FaqRow`) is shared with the full `/faq` page accordion
 * (`faq/full-faq-accordion.tsx`) so the visual/animation contract can't
 * drift between the two (NA-38).
 */
export function FaqAccordion({ items }: { items: FaqAccordionItem[] }) {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <div
      style={{
        background: 'var(--surface-card)',
        border: '1px solid var(--border-default)',
        boxShadow: '0 24px 60px -30px rgba(0,0,0,.7)',
        padding: '6px 30px',
      }}
    >
      {items.map((item, index) => (
        <FaqRow
          key={item.id}
          index={index + 1}
          item={item}
          isOpen={openIndex === index}
          isLast={index === items.length - 1}
          onToggle={() =>
            setOpenIndex((current) => (current === index ? null : index))
          }
        />
      ))}
    </div>
  );
}
