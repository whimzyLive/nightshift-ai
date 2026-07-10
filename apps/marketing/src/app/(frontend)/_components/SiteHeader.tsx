'use client';
import { useState } from 'react';
import { Button, MoonMark } from '@nightshift-ai/ui';
import type { SiteSetting } from '../../../payload-types';

export function SiteHeader({ siteSettings }: { siteSettings?: SiteSetting }) {
  const [open, setOpen] = useState(false);
  const navLinks = siteSettings?.navLinks ?? [];

  return (
    <header className="sticky top-0 z-20 border-b border-default bg-page/80 backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-page items-center justify-between px-6">
        <a
          href="/"
          className="flex items-center gap-2 font-mono text-sm font-semibold text-strong"
        >
          <MoonMark />
          nightshift
        </a>
        <nav className="hidden gap-8 sm:flex">
          {navLinks.map((link, i) => (
            <a
              key={link.id ?? i}
              href={link.href ?? '#'}
              className="text-sm text-body transition-colors duration-200 ease-out hover:text-accent"
            >
              {link.label ?? ''}
            </a>
          ))}
        </nav>
        <div className="hidden sm:block">
          {siteSettings?.githubUrl ? (
            <Button variant="secondary" href={siteSettings.githubUrl}>
              {siteSettings.githubLabel ?? 'GitHub'}
            </Button>
          ) : null}
        </div>
        <button
          type="button"
          className="text-strong sm:hidden"
          aria-label="Toggle navigation"
          aria-expanded={open}
          onClick={() => setOpen((o) => !o)}
        >
          {open ? '✕' : '☰'}
        </button>
      </div>
      {open ? (
        <nav className="flex flex-col gap-4 border-t border-default px-6 py-4 sm:hidden">
          {navLinks.map((link, i) => (
            <a
              key={link.id ?? i}
              href={link.href ?? '#'}
              onClick={() => setOpen(false)}
              className="text-sm text-body hover:text-accent"
            >
              {link.label ?? ''}
            </a>
          ))}
          {siteSettings?.githubUrl ? (
            <Button
              variant="secondary"
              href={siteSettings.githubUrl}
              onClick={() => setOpen(false)}
            >
              {siteSettings.githubLabel ?? 'GitHub'}
            </Button>
          ) : null}
        </nav>
      ) : null}
    </header>
  );
}
