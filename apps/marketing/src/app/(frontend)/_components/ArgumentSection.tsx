import type { WhySdlc } from '../../../payload-types';
import { RichText } from './RichText';

type ArgumentSectionContent = NonNullable<WhySdlc['argumentSections']>[number];

export function ArgumentSection({
  content,
}: {
  content?: ArgumentSectionContent;
}) {
  return (
    <section className="py-10">
      <h2 className="text-2xl font-bold text-strong">
        {content?.heading ?? ''}
      </h2>
      <div className="mt-4 text-body">
        <RichText data={content?.body} />
      </div>
    </section>
  );
}
