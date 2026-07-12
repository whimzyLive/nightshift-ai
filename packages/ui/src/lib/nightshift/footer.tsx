import Link from 'next/link';

import { Logomark } from './logomark';

interface FooterLink {
  label: string;
  href: string;
  external?: boolean;
}

interface FooterColumn {
  title: string;
  links: FooterLink[];
}

const COLUMNS: FooterColumn[] = [
  {
    title: 'Plugin',
    links: [
      { label: 'How it works', href: '/#how-it-works' },
      { label: 'Why SDLC', href: '/why-sdlc' },
      { label: 'FAQ', href: '/faq' },
      { label: 'Install', href: '/#install' },
    ],
  },
  {
    title: 'Project',
    links: [
      {
        label: 'GitHub repo',
        href: 'https://github.com/whimzyLive/nightshift-ai',
        external: true,
      },
      {
        label: 'Docs / changelog',
        href: 'https://github.com/whimzyLive/nightshift-ai/blob/main/CHANGELOG.md',
        external: true,
      },
      {
        label: 'License / MIT',
        href: 'https://github.com/whimzyLive/nightshift-ai/blob/main/LICENSE',
        external: true,
      },
    ],
  },
  {
    title: 'Company',
    links: [{ label: 'The team', href: '/team' }],
  },
];

const linkClasses =
  'block leading-[1.6] font-sans text-sm text-[var(--text-muted)] no-underline transition-colors duration-150 ease-out hover:text-[var(--text-strong)] motion-reduce:transition-none';

/**
 * Glass footer over the sky — three columns (Plugin / Project / Company).
 * Server component: no browser APIs needed.
 */
export function Footer() {
  return (
    <footer
      className="rounded-none border-t px-7 pt-14 pb-7"
      style={{
        background: 'var(--glass-footer-bg)',
        backdropFilter: 'blur(20px) saturate(1.3)',
        WebkitBackdropFilter: 'blur(20px) saturate(1.3)',
        borderColor: 'rgba(255,255,255,0.1)',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.05)',
      }}
    >
      <div className="mx-auto flex max-w-[var(--container-max)] flex-wrap justify-between gap-12">
        <div className="max-w-80">
          <div className="mb-3.5 flex items-center gap-2.5">
            <Logomark size={26} />
            <span className="font-mono text-base font-bold text-[var(--moon-100)]">
              night<span className="text-[var(--accent)]">shift</span>
            </span>
          </div>
          <p className="font-sans text-sm leading-[1.6] text-[var(--text-muted)]">
            Your AI software team that ships while you sleep.
          </p>
        </div>

        <div className="flex flex-wrap gap-14">
          {COLUMNS.map((column) => (
            <div key={column.title} className="flex flex-col gap-3">
              <span className="font-mono text-[11px] tracking-[0.14em] text-[var(--text-dim)] uppercase">
                {column.title}
              </span>
              {column.links.map((link) =>
                link.external ? (
                  <a
                    key={link.label}
                    href={link.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    className={linkClasses}
                  >
                    {link.label}
                  </a>
                ) : (
                  <Link
                    key={link.label}
                    href={link.href}
                    className={linkClasses}
                  >
                    {link.label}
                  </Link>
                ),
              )}
            </div>
          ))}
        </div>
      </div>

      <div
        className="mx-auto mt-10 flex max-w-[var(--container-max)] flex-wrap items-center justify-between gap-3 border-t pt-[22px]"
        style={{ borderColor: 'var(--border-soft)' }}
      >
        <span className="font-mono text-xs text-[var(--text-dim)]">
          Built on Claude Code — agents, commands, skills, and hooks all the way
          down.
        </span>
        <span className="font-mono text-xs text-[var(--text-dim)]">
          MIT © whimzyLive
        </span>
      </div>
    </footer>
  );
}
