'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useState } from 'react';

import { CtaButton } from './button';
import { Logomark } from './logomark';

const DETACH_THRESHOLD_PX = 320;

const NAV_LINKS: { label: string; href: string }[] = [
  { label: 'How it works', href: '/#how-it-works' },
  { label: 'Why SDLC', href: '/why-sdlc' },
  { label: 'The team', href: '/team' },
  { label: 'FAQ', href: '/faq' },
];

const GITHUB_URL = 'https://github.com/whimzyLive/nightshift-ai';

export function isActiveLink(pathname: string, href: string): boolean {
  if (href.startsWith('/#')) return pathname === '/';
  return pathname === href;
}

/**
 * Glass nav — translucent by default, detaches into a floating sharp
 * pill after ~320px of scroll. Hardcoded links (single consumer, see
 * spec NA-30). Reduced motion swaps the detach transition for an instant
 * state change.
 */
export function NavBar() {
  const pathname = usePathname();
  const [floating, setFloating] = useState(false);

  useEffect(() => {
    const onScroll = () => setFloating(window.scrollY > DETACH_THRESHOLD_PX);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const reducedMotionClass = 'motion-reduce:transition-none';

  return (
    <header
      className={`fixed inset-x-0 z-50 flex items-center gap-7 border-b px-7 ${reducedMotionClass} ${
        floating
          ? 'top-[var(--nav-float-top)] mx-auto rounded-none border-[var(--glass-border)] backdrop-blur-[26px] backdrop-saturate-[1.5] transition-[top,max-width,border-radius,background,box-shadow] duration-500 ease-out'
          : 'top-0 w-full rounded-none border-white/[0.08] backdrop-blur-[20px] backdrop-saturate-[1.35] transition-[top,max-width,border-radius,background,box-shadow] duration-500 ease-out'
      }`}
      style={{
        height: 'var(--nav-height)',
        left: floating ? '50%' : undefined,
        transform: floating ? 'translateX(-50%)' : undefined,
        maxWidth: floating ? 'var(--nav-float-max)' : undefined,
        background: floating
          ? 'var(--glass-nav-float-bg)'
          : 'var(--glass-nav-bg)',
        boxShadow: floating
          ? 'var(--nav-float-shadow)'
          : 'inset 0 1px 0 rgba(255,255,255,0.05)',
      }}
    >
      <Link
        href="/"
        aria-label="nightshift"
        className="flex items-center gap-2.5 no-underline"
      >
        <Logomark size={28} />
        <span className="font-mono text-[17px] font-bold tracking-[-0.4px] text-[var(--moon-100)]">
          night<span className="text-[var(--accent)]">shift</span>
        </span>
      </Link>

      <nav className="flex flex-1 items-center gap-1">
        {NAV_LINKS.map((link) => {
          const active = isActiveLink(pathname, link.href);
          return (
            <Link
              key={link.label}
              href={link.href}
              aria-current={active ? 'page' : undefined}
              className={`rounded-none px-3 py-1.5 font-sans text-sm font-medium no-underline transition-colors duration-150 ease-out hover:text-[var(--text-strong)] motion-reduce:transition-none ${
                active
                  ? 'text-[var(--text-strong)]'
                  : 'text-[var(--text-muted)]'
              }`}
            >
              {link.label}
            </Link>
          );
        })}
        <a
          href={GITHUB_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="rounded-none px-3 py-1.5 font-sans text-sm font-medium text-[var(--text-muted)] no-underline transition-colors duration-150 ease-out hover:text-[var(--text-strong)] motion-reduce:transition-none"
        >
          GitHub
        </a>
      </nav>

      <CtaButton href="/#install" className="text-xs">
        Install the plugin
      </CtaButton>
    </header>
  );
}
