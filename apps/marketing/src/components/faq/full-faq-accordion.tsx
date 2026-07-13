'use client';

import { useState } from 'react';

import { Reveal, RevealGroup } from '@nightshift-ai/ui';

import { FaqRow, type FaqAccordionItem } from './faq-row';

export interface FullFaqAccordionGroup {
  key: string;
  eyebrow: string;
  items: Array<FaqAccordionItem & { number: number }>;
}

/**
 * The five solid-card FAQ groups. A single `openId` spans ALL groups
 * (AC2): opening any row replaces the previously open row anywhere on the
 * page; `null` = all closed (first-load state). Row numbering uses
 * `item.number` (= faqOrder) so Q.NN runs continuously across group
 * boundaries (AC1). Reduced-motion is handled by FaqRow's
 * `motion-reduce:transition-none` + the global.css guard (AC5).
 */
export function FullFaqAccordion({
  groups,
}: {
  groups: FullFaqAccordionGroup[];
}) {
  const [openId, setOpenId] = useState<FaqAccordionItem['id'] | null>(null);

  return (
    <div className="flex flex-col" style={{ gap: 40 }}>
      {groups.map((group) => (
        // Each group reveals independently as it scrolls into view: the
        // eyebrow then the solid card stagger in (plain fade-rise, NO
        // scale/blur — the card keeps its `--surface-card` surface and the
        // rows' own height/opacity toggle animation stays untouched).
        <RevealGroup key={group.key} as="div" amount={0.2}>
          <Reveal
            as="p"
            className="font-mono uppercase"
            style={{
              fontSize: 12,
              letterSpacing: '.16em',
              color: 'var(--accent)',
              margin: '0 0 14px',
            }}
          >
            {group.eyebrow}
          </Reveal>
          <Reveal
            style={{
              background: 'var(--surface-card)',
              border: '1px solid var(--border-default)',
              boxShadow: '0 24px 60px -30px rgba(0,0,0,.7)',
              padding: '4px 28px',
            }}
          >
            {group.items.map((item, i) => (
              <FaqRow
                key={item.id}
                index={item.number}
                item={item}
                isOpen={openId === item.id}
                isLast={i === group.items.length - 1}
                onToggle={() =>
                  setOpenId((cur) => (cur === item.id ? null : item.id))
                }
              />
            ))}
          </Reveal>
        </RevealGroup>
      ))}
    </div>
  );
}
