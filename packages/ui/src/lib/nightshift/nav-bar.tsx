'use client';

import { AnimatePresence, motion } from 'motion/react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';

import { CtaButton } from './button';
import { Logomark } from './logomark';

const DETACH_THRESHOLD_PX = 320;
// Tailwind `lg`. Below this the bar stays a full-length header with a
// hamburger — the floating pill only reads well at desktop widths.
const LG_BREAKPOINT_PX = 1024;

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

function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  );
}

/**
 * GitHub octicon mark, tinted terracotta with a soft accent glow that warms
 * further on hover (the parent link owns the `group` hover state).
 */
function GitHubMark() {
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

/** Three-bar hamburger glyph. */
function MenuGlyph() {
  return (
    <svg viewBox="0 0 24 24" width={22} height={22} aria-hidden="true">
      <path
        d="M4 7h16M4 12h16M4 17h16"
        stroke="currentColor"
        strokeWidth={1.75}
        strokeLinecap="round"
      />
    </svg>
  );
}

/** Close (✕) glyph. */
function CloseGlyph() {
  return (
    <svg viewBox="0 0 24 24" width={20} height={20} aria-hidden="true">
      <path
        d="M6 6l12 12M18 6L6 18"
        stroke="currentColor"
        strokeWidth={1.75}
        strokeLinecap="round"
      />
    </svg>
  );
}

/**
 * Full-screen overlay menu shown below the `lg` breakpoint. Reuses NAV_LINKS
 * and the shared CtaButton so the mobile menu stays in lock-step with the
 * desktop bar. Owns its own a11y (dialog role, Esc, scroll-lock, focus
 * return); the parent NavBar only toggles `open`.
 */
function MobileOverlay({
  open,
  onClose,
  pathname,
  returnFocusTo,
}: {
  open: boolean;
  onClose: () => void;
  pathname: string;
  returnFocusTo: React.RefObject<HTMLButtonElement | null>;
}) {
  const closeRef = useRef<HTMLButtonElement>(null);
  const reduce = prefersReducedMotion();

  // Esc to close + body scroll-lock, active only while open.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    closeRef.current?.focus();
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
      returnFocusTo.current?.focus();
    };
  }, [open, onClose, returnFocusTo]);

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          role="dialog"
          aria-modal="true"
          aria-label="Site menu"
          className="fixed inset-x-0 top-0 z-[60] flex h-[100dvh] flex-col overflow-y-auto overscroll-contain bg-[var(--bg-page)] px-7 py-6"
          initial={reduce ? false : { opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={reduce ? { opacity: 0 } : { opacity: 0, y: -8 }}
          transition={{ duration: reduce ? 0 : 0.2, ease: 'easeOut' }}
        >
          <div className="flex items-center justify-between">
            <Link
              href="/"
              aria-label="nightshift"
              onClick={onClose}
              className="flex items-center gap-2.5 no-underline"
            >
              <Logomark size={28} />
              <span className="font-mono text-[17px] font-bold tracking-[-0.4px] text-[var(--moon-100)]">
                night<span className="text-[var(--accent)]">shift</span>
              </span>
            </Link>
            <button
              ref={closeRef}
              type="button"
              onClick={onClose}
              aria-label="Close menu"
              className="flex items-center gap-2 rounded-none border border-[var(--border-default)] px-3 py-1.5 font-sans text-sm font-medium text-[var(--text-muted)] transition-colors duration-150 ease-out hover:text-[var(--text-strong)] focus-visible:shadow-[var(--glow-focus)] focus-visible:outline-none motion-reduce:transition-none"
            >
              <CloseGlyph />
              Close
            </button>
          </div>

          <nav className="flex flex-1 flex-col justify-center gap-2">
            {NAV_LINKS.map((link, i) => {
              const active = isActiveLink(pathname, link.href);
              return (
                <motion.div
                  key={link.label}
                  initial={reduce ? false : { opacity: 0, y: 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{
                    duration: reduce ? 0 : 0.25,
                    delay: reduce ? 0 : 0.05 + i * 0.05,
                    ease: 'easeOut',
                  }}
                >
                  <Link
                    href={link.href}
                    aria-current={active ? 'page' : undefined}
                    onClick={onClose}
                    className={`block py-2 font-sans text-3xl font-semibold tracking-[-0.5px] no-underline transition-colors duration-150 ease-out motion-reduce:transition-none ${
                      active
                        ? 'text-[var(--accent)]'
                        : 'text-[var(--text-strong)] hover:text-[var(--accent)]'
                    }`}
                  >
                    {link.label}
                  </Link>
                </motion.div>
              );
            })}
          </nav>

          <div className="flex items-center gap-4">
            <CtaButton
              href={GITHUB_URL}
              target="_blank"
              rel="noopener noreferrer"
              aria-label="GitHub"
              variant="secondary"
              size="md"
              onClick={onClose}
              className="font-mono"
            >
              <GitHubMark />
              <span aria-hidden="true">4</span>
            </CtaButton>
            <CtaButton
              href="/#install"
              onClick={onClose}
              className="flex-1 whitespace-nowrap"
            >
              Install the plugin
            </CtaButton>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

/**
 * Glass nav — translucent by default, detaches into a floating sharp
 * pill after ~320px of scroll. Hardcoded links (single consumer, see
 * spec NA-30). Reduced motion swaps the detach transition for an instant
 * state change.
 *
 * Below `lg` the inline links and CTAs collapse into a hamburger that opens
 * a full-screen overlay menu (see MobileOverlay).
 */
export function NavBar() {
  const pathname = usePathname();
  const [floating, setFloating] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const toggleRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    // Only detach into the floating pill at `lg`+ — below that the bar stays
    // full-length. Re-evaluated on resize so crossing the breakpoint re-docks.
    const update = () =>
      setFloating(
        window.innerWidth >= LG_BREAKPOINT_PX &&
          window.scrollY > DETACH_THRESHOLD_PX,
      );
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    update();
    return () => {
      window.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
    };
  }, []);

  // Close the overlay on route change so navigating never leaves it open.
  useEffect(() => {
    setMenuOpen(false);
  }, [pathname]);

  const reducedMotionClass = 'motion-reduce:transition-none';

  return (
    <>
      <header
        className={`fixed inset-x-0 z-50 flex items-center gap-7 border-b px-7 ${reducedMotionClass} ${
          floating
            ? 'top-[var(--nav-float-top)] mx-auto rounded-none border-[var(--glass-border)] backdrop-blur-[26px] backdrop-saturate-[1.5] transition-[top,max-width,border-radius,background,box-shadow] duration-500 ease-out'
            : 'top-0 w-full rounded-none border-white/[0.08] backdrop-blur-[20px] backdrop-saturate-[1.35] transition-[top,max-width,border-radius,background,box-shadow] duration-500 ease-out'
        }`}
        style={{
          height: 'var(--nav-height)',
          // Floating: hug the content (so nothing overflows the pill), centred,
          // capped at the design max / viewport width. `right: auto` releases
          // the base `inset-x-0` right:0 that would otherwise pin the width.
          left: floating ? '50%' : undefined,
          right: floating ? 'auto' : undefined,
          transform: floating ? 'translateX(-50%)' : undefined,
          width: floating ? 'max-content' : undefined,
          maxWidth: floating
            ? 'min(var(--nav-float-max), calc(100vw - 48px))'
            : undefined,
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

        <nav className="hidden flex-1 items-center gap-1 lg:flex">
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

        <div className="hidden items-center gap-7 lg:flex">
          <CtaButton
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            aria-label="GitHub"
            variant="secondary"
            size="sm"
            className="font-mono"
          >
            <GitHubMark />
            <span aria-hidden="true">4</span>
          </CtaButton>

          <CtaButton href="/#install" className="whitespace-nowrap text-xs">
            Install the plugin
          </CtaButton>
        </div>

        <button
          ref={toggleRef}
          type="button"
          onClick={() => setMenuOpen(true)}
          aria-label="Open menu"
          aria-expanded={menuOpen}
          aria-controls="mobile-menu"
          className="ml-auto flex items-center justify-center rounded-none p-1.5 text-[var(--moon-100)] transition-colors duration-150 ease-out hover:text-[var(--text-strong)] focus-visible:shadow-[var(--glow-focus)] focus-visible:outline-none motion-reduce:transition-none lg:hidden"
        >
          <MenuGlyph />
        </button>
      </header>

      <div id="mobile-menu" className="lg:hidden">
        <MobileOverlay
          open={menuOpen}
          onClose={() => setMenuOpen(false)}
          pathname={pathname}
          returnFocusTo={toggleRef}
        />
      </div>
    </>
  );
}
