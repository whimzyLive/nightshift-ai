'use client';
import { useState } from 'react';
import type { WhySdlc } from '../../../payload-types';
import { RichText } from './RichText';

export function WhySdlcFaq({ content }: { content?: WhySdlc['faq'] }) {
  const items = content?.items ?? [];
  const [openId, setOpenId] = useState<string | number | null>(null);

  return (
    <section className="border-t border-default py-16">
      <div className="divide-y divide-default">
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
    </section>
  );
}
