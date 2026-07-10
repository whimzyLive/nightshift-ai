import { MoonMark } from '@nightshift-ai/ui';
import type { SiteSetting } from '../../../payload-types';

export function SiteFooter({ siteSettings }: { siteSettings?: SiteSetting }) {
  const columns = siteSettings?.footerColumns ?? [];

  return (
    <footer className="border-t border-default bg-void px-6 py-16">
      {/* Brand lockup weighted against the nav columns for hierarchy, per
       * the Footer component spec (brand + tagline left, columns right). */}
      <div className="mx-auto grid max-w-page gap-12 sm:grid-cols-[1fr_2fr]">
        <a
          href="/"
          className="flex items-center gap-2 font-mono text-sm font-semibold text-strong"
        >
          <MoonMark />
          nightshift
        </a>
        <div className="grid gap-10 sm:grid-cols-3">
          {columns.map((column, i) => (
            <div key={column.id ?? i}>
              <div className="font-mono text-xs uppercase tracking-eyebrow text-dim">
                {column.heading ?? ''}
              </div>
              <ul className="mt-4 flex flex-col gap-2">
                {(column.links ?? []).map((link, j) => (
                  <li key={link.id ?? j}>
                    <a
                      href={link.href ?? '#'}
                      className="text-sm text-body transition-colors duration-200 ease-out hover:text-accent"
                    >
                      {link.label ?? ''}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </footer>
  );
}
