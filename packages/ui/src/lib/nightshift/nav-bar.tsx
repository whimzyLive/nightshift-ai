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
 * GitHub octicon mark, tinted terracotta with a soft accent glow that warms
 * further on hover (the parent link owns the `group` hover state).
 */
function GithubMark() {
  return (
    <svg
      viewBox="0 0 16 16"
      width={16}
      height={16}
      aria-hidden="true"
      className="transition-[filter] duration-150 ease-out"
      style={{
        fill: 'var(--moon-100)',
        filter: 'drop-shadow(0 0 5px rgba(124,147,240,0.5))',
      }}
    >
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.65 7.65 0 012-.27c.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
    </svg>
  );
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
              className={`rounded-none px-3 py-1.5 font-sans text-sm font-medium whitespace-nowrap no-underline transition-colors duration-150 ease-out hover:text-[var(--text-strong)] motion-reduce:transition-none ${
                active
                  ? 'text-[var(--text-strong)]'
                  : 'text-[var(--text-muted)]'
              }`}
            >
              {link.label}
            </Link>
          );
        })}
      </nav>

      <CtaButton
        href={GITHUB_URL}
        target="_blank"
        rel="noopener noreferrer"
        aria-label="GitHub"
        variant="secondary"
        size="sm"
        className="font-mono"
      >
        <GithubMark />
        <span aria-hidden="true">4</span>
      </CtaButton>

      <CtaButton href="/#install" className="whitespace-nowrap text-xs">
        Install the plugin
      </CtaButton>
    </header>
  );
}
