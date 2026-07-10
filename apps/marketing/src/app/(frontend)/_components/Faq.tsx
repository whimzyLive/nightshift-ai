'use client';
import { useState } from 'react';
import { Eyebrow } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';
import { RichText } from './RichText';

export function Faq({ content }: { content?: Home['faq'] }) {
  const items = content?.items ?? [];
  const [openId, setOpenId] = useState<string | number | null>(null);

  return (
    <section id="faq" className="mx-auto max-w-3xl px-6 py-24">
      {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
      <div className="mt-10 divide-y divide-default">
        {items.map((item, i) => {
          const id = item.id ?? i;
          const open = openId === id;
          return (
            <div key={id} className="py-4">
              <button
                type="button"
                onClick={() => setOpenId(open ? null : id)}
                className="flex w-full items-center justify-between text-left font-medium text-strong"
                aria-expanded={open}
              >
                {item.question ?? ''}
                <span aria-hidden>{open ? '−' : '+'}</span>
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
    </section>
  );
}
