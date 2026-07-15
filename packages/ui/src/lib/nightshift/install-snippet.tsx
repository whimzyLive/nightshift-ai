'use client';

import { useEffect, useState } from 'react';
import { AnimatePresence, motion } from 'motion/react';

import { CtaButton } from './button';

export interface InstallSnippetProps {
  /** The exact command text — copied verbatim, never re-derived. */
  command: string;
  /** Leading prompt glyph shown before the command. Default: '$'. */
  prompt?: string;
  className?: string;
}

const COPIED_RESET_MS = 1500;

/**
 * Mono command row with a copy-to-clipboard button. Never throws when the
 * Clipboard API is unavailable or rejects (private browsing, permissions
 * policy, insecure context) — the command stays visible/selectable either
 * way, so manual copy is always possible.
 */
export function InstallSnippet({
  command,
  prompt = '$',
  className = '',
}: InstallSnippetProps) {
  const [copied, setCopied] = useState(false);

  // Auto-revert the "copied" confirmation after ~1.5s.
  useEffect(() => {
    if (!copied) return;
    const id = setTimeout(() => setCopied(false), COPIED_RESET_MS);
    return () => clearTimeout(id);
  }, [copied]);

  const handleCopy = () => {
    const clipboard =
      typeof navigator !== 'undefined' ? navigator.clipboard : undefined;
    if (!clipboard?.writeText) return; // unsupported — command stays selectable

    Promise.resolve(clipboard.writeText(command))
      .then(() => setCopied(true))
      .catch(() => {
        // write rejected — no throw, no error dialog, nothing to revert
      });
  };

  return (
    <div
      className={`flex items-center justify-between gap-3 rounded-none border font-mono text-sm ${className}`}
      style={{
        background: 'var(--surface-terminal)',
        borderColor: 'var(--border-default)',
        padding: '12px 14px',
      }}
    >
      <span
        className="min-w-0 flex-1 truncate"
        style={{ color: 'var(--text-body)' }}
      >
        <span
          aria-hidden="true"
          style={{ color: 'var(--code-prompt)', marginRight: 8 }}
        >
          {prompt}
        </span>
        {command}
      </span>
      <CtaButton
        type="button"
        onClick={handleCopy}
        aria-label={`Copy: ${command}`}
        variant="primary"
        size="sm"
        className="flex-none overflow-hidden font-mono text-xs tracking-[0.02em] uppercase"
      >
        <AnimatePresence mode="wait" initial={false}>
          <motion.span
            key={copied ? 'copied' : 'copy'}
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 6 }}
            transition={{ duration: 0.15, ease: 'easeOut' }}
            className="block"
          >
            {copied ? 'copied' : 'copy'}
          </motion.span>
        </AnimatePresence>
      </CtaButton>
    </div>
  );
}
