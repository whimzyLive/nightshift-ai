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
    <section className="relative overflow-hidden bg-page px-6 pb-24 pt-28 text-center sm:pb-28 sm:pt-32">
      {/* Hero recipe: moon-glow + starfield behind, one accent focal point
       * (.claude/skills/nightshift-design/references/patterns.md). Content
       * sits at z-10, motifs stay non-interactive at z-0. */}
      <div aria-hidden className="moon-glow" />
      <div aria-hidden className="starfield" />
      <div className="relative z-10 mx-auto max-w-3xl">
        <h1 className="text-4xl font-extrabold tracking-tight text-strong sm:text-5xl lg:text-6xl">
          {content?.headline ?? ''}
        </h1>
        <p className="mt-6 text-md leading-relaxed text-muted">
          {content?.subheadline ?? ''}
        </p>
        <div className="mt-10 flex flex-col items-center gap-5">
          {siteSettings?.installCommand ? (
            <InstallSnippet
              command={siteSettings.installCommand}
              label={content?.installCtaLabel ?? undefined}
            />
          ) : null}
          {siteSettings?.githubUrl ? (
            <Button variant="secondary" href={siteSettings.githubUrl}>
              {content?.starCtaLabel ?? 'Star on GitHub'}
            </Button>
          ) : null}
        </div>
      </div>
    </section>
  );
}
