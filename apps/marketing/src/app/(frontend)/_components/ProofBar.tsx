import type { Home } from '../../../payload-types';

export function ProofBar({ content }: { content?: Home['proofBar'] }) {
  const items = content?.items ?? [];
  return (
    <section className="border-y border-default bg-void px-6 py-10">
      <div className="mx-auto flex max-w-5xl flex-wrap justify-center gap-10 text-center">
        {items.map((item, i) => (
          <div key={item.id ?? i}>
            <div className="font-mono text-2xl font-bold text-strong">
              {item.value ?? ''}
            </div>
            <div className="text-sm text-muted">{item.label ?? ''}</div>
          </div>
        ))}
      </div>
    </section>
  );
}
