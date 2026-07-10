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
    <section className="relative overflow-hidden border-t border-default bg-void px-6 py-20 text-center sm:py-28">
      {/* Bookends the hero's moon-glow — the "one more push" closing surface. */}
      <div aria-hidden className="moon-glow" />
      <div className="relative z-10 mx-auto max-w-copy">
        <h2 className="text-3xl font-extrabold tracking-tight text-strong sm:text-4xl">
          {content?.heading ?? ''}
        </h2>
        <p className="mt-4 text-lg leading-relaxed text-muted">
          {content?.body ?? ''}
        </p>
        <div className="mt-10 flex flex-col items-center gap-5">
          {siteSettings?.installCommand ? (
            <InstallSnippet command={siteSettings.installCommand} />
          ) : null}
          {siteSettings?.githubUrl ? (
            <Button variant="secondary" href={siteSettings.githubUrl}>
              {starCtaLabel ?? 'Star on GitHub'}
            </Button>
          ) : null}
        </div>
      </div>
    </section>
  );
}
