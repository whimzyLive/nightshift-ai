import type { SiteSetting } from '../../../payload-types';

export function SiteFooter({ siteSettings }: { siteSettings?: SiteSetting }) {
  const columns = siteSettings?.footerColumns ?? [];

  return (
    <footer className="border-t border-default bg-void px-6 py-16">
      <div className="mx-auto grid max-w-5xl gap-10 sm:grid-cols-3">
        {columns.map((column, i) => (
          <div key={column.id ?? i}>
            <div className="font-mono text-xs uppercase tracking-widest text-dim">
              {column.heading ?? ''}
            </div>
            <ul className="mt-4 flex flex-col gap-2">
              {(column.links ?? []).map((link, j) => (
                <li key={link.id ?? j}>
                  <a
                    href={link.href ?? '#'}
                    className="text-sm text-body hover:text-strong"
                  >
                    {link.label ?? ''}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </footer>
  );
}
