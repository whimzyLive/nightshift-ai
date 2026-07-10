import type { Home } from '../../../payload-types';

export function ProofBar({ content }: { content?: Home['proofBar'] }) {
  const items = content?.items ?? [];
  return (
    <section className="border-y border-default bg-void px-6 py-12">
      {/* Lead with proof, not adjectives — mono numerals, hairline dividers
       * between stats read as a terminal-status row rather than a plain
       * feature strip. */}
      <div className="mx-auto flex max-w-page flex-wrap justify-center divide-x divide-default text-center">
        {items.map((item, i) => (
          <div key={item.id ?? i} className="px-8 py-2 first:pl-0 last:pr-0">
            <div className="font-mono text-2xl font-bold tracking-tight text-strong">
              {item.value ?? ''}
            </div>
            <div className="mt-1 font-mono text-xs uppercase tracking-eyebrow text-dim">
              {item.label ?? ''}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
