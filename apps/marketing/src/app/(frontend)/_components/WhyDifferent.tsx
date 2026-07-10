import { Eyebrow, Card } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

export function WhyDifferent({ content }: { content?: Home['whyDifferent'] }) {
  const cards = content?.cards ?? [];
  return (
    <section className="border-t border-default px-6 py-20 sm:py-24">
      <div className="mx-auto max-w-page">
        {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
        <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {cards.map((card, i) => (
            <Card key={card.id ?? i}>
              <div className="font-semibold text-strong">
                {card.heading ?? ''}
              </div>
              <p className="mt-2 text-sm leading-relaxed text-muted">
                {card.body ?? ''}
              </p>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}
