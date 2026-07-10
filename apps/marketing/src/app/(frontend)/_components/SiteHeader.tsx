'use client';
import { useState } from 'react';
import { Button } from '@nightshift-ai/ui';
import type { SiteSetting } from '../../../payload-types';

export function SiteHeader({ siteSettings }: { siteSettings?: SiteSetting }) {
  const [open, setOpen] = useState(false);
  const navLinks = siteSettings?.navLinks ?? [];

  return (
    <header className="sticky top-0 z-10 border-b border-default bg-page/95 backdrop-blur">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
        <a href="/" className="font-mono text-sm font-semibold text-strong">
          nightshift
        </a>
        <nav className="hidden gap-6 sm:flex">
          {navLinks.map((link, i) => (
            <a
              key={link.id ?? i}
              href={link.href ?? '#'}
              className="text-sm text-body hover:text-strong"
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
          className="sm:hidden"
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
              className="text-sm text-body"
            >
              {link.label ?? ''}
            </a>
          ))}
        </nav>
      ) : null}
    </header>
  );
}
