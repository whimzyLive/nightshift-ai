import { Eyebrow } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

export function Problem({ content }: { content?: Home['problem'] }) {
  const points = content?.points ?? [];
  return (
    <section className="px-6 py-20 sm:py-24">
      <div className="mx-auto max-w-page">
        {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
        <p className="mt-4 max-w-copy text-lg leading-relaxed text-body">
          {content?.body ?? ''}
        </p>
        <div className="mt-10 grid gap-6 sm:grid-cols-3">
          {points.map((point, i) => (
            <div
              key={point.id ?? i}
              className="border-l-2 border-line-accent pl-4"
            >
              <div className="font-semibold text-strong">
                {point.lead ?? ''}
              </div>
              <div className="mt-1 text-sm text-muted">{point.body ?? ''}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
