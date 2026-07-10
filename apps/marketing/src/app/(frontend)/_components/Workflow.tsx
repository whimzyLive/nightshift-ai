import { Eyebrow, Card } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

export function Workflow({ content }: { content?: Home['workflow'] }) {
  const blocks = content?.blocks ?? [];
  return (
    <section id="workflow" className="mx-auto max-w-5xl px-6 py-24">
      {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
      <div className="mt-10 grid gap-6 sm:grid-cols-2">
        {blocks.map((block, i) => (
          <Card key={block.id ?? i}>
            <div className="font-semibold text-strong">{block.label ?? ''}</div>
            <p className="mt-2 text-sm text-muted">{block.body ?? ''}</p>
          </Card>
        ))}
      </div>
    </section>
  );
}
