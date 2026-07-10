import { Eyebrow } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

export function Problem({ content }: { content?: Home['problem'] }) {
  const points = content?.points ?? [];
  return (
    <section className="mx-auto max-w-5xl px-6 py-24">
      {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
      <p className="mt-4 max-w-2xl text-lg text-body">{content?.body ?? ''}</p>
      <div className="mt-10 grid gap-6 sm:grid-cols-3">
        {points.map((point, i) => (
          <div key={point.id ?? i}>
            <div className="font-semibold text-strong">{point.lead ?? ''}</div>
            <div className="mt-1 text-sm text-muted">{point.body ?? ''}</div>
          </div>
        ))}
      </div>
    </section>
  );
}
