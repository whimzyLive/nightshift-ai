import { Eyebrow } from '@nightshift-ai/ui';
import type { WhySdlc } from '../../../payload-types';
import { RichText } from './RichText';

export function WhySdlcHero({ content }: { content?: WhySdlc['hero'] }) {
  return (
    <section className="py-12 text-center">
      {content?.eyebrow ? <Eyebrow>{content.eyebrow}</Eyebrow> : null}
      <h1 className="mt-4 text-4xl font-extrabold tracking-tight text-strong">
        {content?.h1 ?? ''}
      </h1>
      <div className="mt-6 text-lg text-body">
        <RichText data={content?.intro} />
      </div>
    </section>
  );
}
