import { InstallSnippet, Button } from '@nightshift-ai/ui';
import type { Home, SiteSetting } from '../../../payload-types';

export function FinalCta({
  content,
  siteSettings,
  starCtaLabel,
}: {
  content?: Home['finalCta'];
  siteSettings?: SiteSetting;
  /** Shared with Hero's identical GitHub CTA — sourced from `home.hero.starCtaLabel`. */
  starCtaLabel?: string | null;
}) {
  return (
    <section className="mx-auto max-w-3xl px-6 py-24 text-center">
      <h2 className="text-3xl font-bold text-strong">
        {content?.heading ?? ''}
      </h2>
      <p className="mt-4 text-lg text-muted">{content?.body ?? ''}</p>
      <div className="mt-8 flex flex-col items-center gap-4">
        {siteSettings?.installCommand ? (
          <InstallSnippet command={siteSettings.installCommand} />
        ) : null}
        {siteSettings?.githubUrl ? (
          <Button variant="secondary" href={siteSettings.githubUrl}>
            {starCtaLabel ?? 'Star on GitHub'}
          </Button>
        ) : null}
      </div>
    </section>
  );
}
