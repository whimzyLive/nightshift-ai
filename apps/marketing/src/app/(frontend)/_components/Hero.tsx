import { Button, InstallSnippet } from '@nightshift-ai/ui';
import type { Home, SiteSetting } from '../../../payload-types';

export function Hero({
  content,
  siteSettings,
}: {
  content?: Home['hero'];
  siteSettings?: SiteSetting;
}) {
  return (
    <section className="mx-auto max-w-5xl px-6 py-24 text-center">
      <h1 className="text-5xl font-bold text-strong">
        {content?.headline ?? ''}
      </h1>
      <p className="mt-6 text-lg text-muted">{content?.subheadline ?? ''}</p>
      <div className="mt-8 flex flex-col items-center gap-4">
        {siteSettings?.installCommand ? (
          <InstallSnippet command={siteSettings.installCommand} />
        ) : null}
        {siteSettings?.githubUrl ? (
          <Button variant="secondary" href={siteSettings.githubUrl}>
            {content?.starCtaLabel ?? 'Star on GitHub'}
          </Button>
        ) : null}
      </div>
    </section>
  );
}
