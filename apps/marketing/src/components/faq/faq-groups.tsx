import { RichText } from '@payloadcms/richtext-lexical/react';

import {
  FullFaqAccordion,
  type FullFaqAccordionGroup,
} from './full-faq-accordion';

import type { FaqPageGroup } from '../../lib/faq';

/**
 * The `/faq` page's grouped accordion section. Server component: `groups`
 * arrives already resolved from the page's top-level async boundary (see
 * (frontend)/faq/page.tsx) — only converts each answer's Lexical JSON to
 * JSX server-side via `<RichText>`, mirroring `FaqPreview`'s usage. Empty
 * groups are skipped (no empty solid card); returns `null` entirely when
 * `getFaqPageGroups()` came back `[]` so the page never throws.
 */
export function FaqGroups({ groups }: { groups: FaqPageGroup[] }) {
  const nonEmpty = groups.filter((g) => g.items.length > 0);
  if (nonEmpty.length === 0) return null;

  const clientGroups: FullFaqAccordionGroup[] = nonEmpty.map((g) => ({
    key: g.key ?? 'ungrouped',
    eyebrow: g.eyebrow,
    items: g.items.map((item) => ({
      id: item.id,
      number: item.number,
      question: item.question,
      answer: <RichText data={item.answer} disableContainer />,
    })),
  }));

  return (
    <section style={{ padding: '56px 28px 72px' }}>
      <div className="mx-auto" style={{ maxWidth: 860 }}>
        <FullFaqAccordion groups={clientGroups} />
      </div>
    </section>
  );
}
