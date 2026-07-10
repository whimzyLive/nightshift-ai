'use client';
import { useState } from 'react';

type CopyState = 'idle' | 'copied' | 'failed';

const ARIA_LABEL_BY_STATE: Record<CopyState, string> = {
  idle: 'Copy install command',
  copied: 'Copied install command',
  failed: 'Failed to copy install command',
};

const LABEL_BY_STATE: Record<CopyState, string> = {
  idle: 'Copy',
  copied: 'Copied',
  failed: 'Failed',
};

export function InstallSnippet({
  command,
  label,
}: {
  command: string;
  /** Optional uppercase mono caption rendered above the command line. */
  label?: string;
}) {
  const [state, setState] = useState<CopyState>('idle');
  const copy = async () => {
    // `navigator.clipboard` is undefined outside secure contexts (plain
    // HTTP, some embedded webviews) — guard existence and swallow a
    // rejected writeText() so the button degrades to a visible "Failed"
    // state instead of an unhandled promise rejection.
    try {
      if (!navigator.clipboard) throw new Error('Clipboard API unavailable');
      await navigator.clipboard.writeText(command);
      setState('copied');
    } catch {
      setState('failed');
    } finally {
      setTimeout(() => setState('idle'), 1500);
    }
  };
  return (
    <div className="flex flex-col gap-2">
      {label ? (
        <span className="font-mono text-xs uppercase tracking-widest text-dim">
          {label}
        </span>
      ) : null}
      <div className="flex items-center justify-between gap-4 rounded-md bg-surface-terminal px-4 py-3 font-mono text-sm text-body">
        <code>{command}</code>
        <button
          type="button"
          onClick={copy}
          aria-label={ARIA_LABEL_BY_STATE[state]}
          className="text-accent hover:text-accent-hover"
        >
          {LABEL_BY_STATE[state]}
        </button>
      </div>
    </div>
  );
}
