'use client';

import { useState } from 'react';

import styles from './install-snippet.module.css';

export interface InstallSnippetProps {
  /** @default '/plugin install sdlc@nightshift' */
  command?: string;
  /** @default '$' */
  prompt?: string;
  /** Optional uppercase mono caption above the snippet. */
  label?: string;
  /** Copy-button label. @default 'copy' */
  copyLabel?: string;
}

const COPIED_RESET_MS = 1600;

/**
 * nightshift InstallSnippet — the "install in 60 seconds" affordance.
 * Copy-to-clipboard command line; the copy button confirms inline.
 */
export function InstallSnippet({
  command = '/plugin install sdlc@nightshift',
  prompt = '$',
  label,
  copyLabel = 'copy',
}: InstallSnippetProps) {
  const [copied, setCopied] = useState(false);

  async function handleCopy() {
    try {
      await navigator.clipboard?.writeText(command);
    } catch {
      // Clipboard API unavailable (unsupported browser, insecure context) —
      // the command is still visible and selectable, so this is non-fatal.
    }
    setCopied(true);
    setTimeout(() => setCopied(false), COPIED_RESET_MS);
  }

  return (
    <div className={styles.wrapper}>
      {label && <span className={styles.label}>{label}</span>}
      <div className={styles.row}>
        <span className={styles.prompt} aria-hidden="true">
          {prompt}
        </span>
        <code className={styles.command}>{command}</code>
        <button
          type="button"
          onClick={handleCopy}
          aria-label={copied ? 'Copied' : `Copy ${copyLabel === 'copy' ? 'command' : copyLabel}`}
          className={`${styles.copyBtn} ${copied ? styles.copied : ''}`}
        >
          {copied ? 'copied ✓' : copyLabel}
        </button>
      </div>
    </div>
  );
}

export default InstallSnippet;
