import { Eyebrow, Button } from '@nightshift-ai/ui';
import type { Home } from '../../../payload-types';

export function Control({ content }: { content?: Home['control'] }) {
  return (
    <section className="mx-auto max-w-3xl px-6 py-24 text-center">
      {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
      <p className="mt-4 text-lg text-body">{content?.body ?? ''}</p>
      {content?.linkHref ? (
        <div className="mt-8">
          <Button variant="secondary" href={content.linkHref}>
            {content?.linkLabel ?? ''}
          </Button>
        </div>
      ) : null}
    </section>
  );
}
