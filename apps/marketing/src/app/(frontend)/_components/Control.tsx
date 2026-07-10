import { Eyebrow, Button } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

export function Control({ content }: { content?: Home['control'] }) {
  return (
    <section className="border-t border-default bg-void px-6 py-20 text-center sm:py-24">
      <div className="mx-auto max-w-copy">
        {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
        <p className="mt-6 border-l-2 border-line-accent pl-6 text-left text-lg leading-relaxed text-body">
          {content?.body ?? ''}
        </p>
        {content?.linkHref ? (
          <div className="mt-8">
            <Button variant="secondary" href={content.linkHref}>
              {content?.linkLabel ?? ''}
            </Button>
          </div>
        ) : null}
      </div>
    </section>
  );
}
