import { Eyebrow, Card } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

// The workflow is told as day → night → morning, in that order (the seed
// content mirrors this — see docs/gtm/site-brief.md). No dedicated CMS
// field carries which period a block is, so the top accent color follows
// array position: the middle block is "night" (cool indigo, the plugin
// running unattended), the outer two are "day"/"morning" (warm terracotta,
// a human at the keyboard).
const PERIOD_ACCENT = [
  'border-t-line-accent',
  'border-t-link',
  'border-t-line-accent',
];

export function Workflow({ content }: { content?: Home['workflow'] }) {
  const blocks = content?.blocks ?? [];
  return (
    <section
      id="workflow"
      className="border-t border-default bg-void px-6 py-20 sm:py-24"
    >
      <div className="mx-auto max-w-page">
        {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
        <div className="mt-10 grid gap-6 sm:grid-cols-3">
          {blocks.map((block, i) => (
            <Card
              key={block.id ?? i}
              className={`border-t-2 ${PERIOD_ACCENT[i % PERIOD_ACCENT.length]}`}
            >
              <div className="font-semibold text-strong">
                {block.label ?? ''}
              </div>
              <p className="mt-2 text-sm leading-relaxed text-muted">
                {block.body ?? ''}
              </p>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}
