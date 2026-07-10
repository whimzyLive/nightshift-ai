'use client';
import { useState } from 'react';
import { Eyebrow } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';
import { RichText } from './RichText';

export function Faq({ content }: { content?: Home['faq'] }) {
  const items = content?.items ?? [];
  const [openId, setOpenId] = useState<string | number | null>(null);

  return (
    <section id="faq" className="border-t border-default px-6 py-20 sm:py-24">
      <div className="mx-auto max-w-copy">
        {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
        <div className="mt-10 divide-y divide-default">
          {items.map((item, i) => {
            const id = item.id ?? i;
            const open = openId === id;
            return (
              <div key={id} className="py-5">
                <button
                  type="button"
                  onClick={() => setOpenId(open ? null : id)}
                  className="flex w-full items-center justify-between gap-4 text-left font-medium text-strong transition-colors duration-200 ease-out hover:text-accent"
                  aria-expanded={open}
                >
                  {item.question ?? ''}
                  <span aria-hidden className="shrink-0 font-mono text-accent">
                    {open ? '−' : '+'}
                  </span>
                </button>
                {open ? (
                  <div className="mt-3 text-sm text-body">
                    <RichText data={item.answer} />
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
