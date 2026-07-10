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
        <span className="font-mono text-xs uppercase tracking-eyebrow text-dim">
          {label}
        </span>
      ) : null}
      {/* Terminal-well recipe: surface-terminal + hairline that warms to
       * accent on hover (.claude/skills/nightshift-design/references/patterns.md
       * "Terminal-on-glass"). Each line gets its own `$` prompt — the install
       * command is two chained lines (marketplace add, then install), so a
       * single shared prompt would misread as one command. */}
      <div className="flex items-start justify-between gap-4 rounded-md border border-default bg-surface-terminal px-4 py-3 font-mono text-sm text-body shadow-elev-2 transition duration-200 ease-out hover:border-line-accent">
        {/* One <code> per line (not one <span> wrapping the whole block) —
         * a bare <div>/<span> row wrapper isn't valid phrasing content
         * inside <code>, and keeps the command text out of any <span>. */}
        <div className="flex flex-col gap-1">
          {command.split('\n').map((line, i) => (
            <code key={i} className="flex items-center gap-2">
              <span aria-hidden className="text-accent">
                $
              </span>
              {line}
            </code>
          ))}
        </div>
        <button
          type="button"
          onClick={copy}
          aria-label={ARIA_LABEL_BY_STATE[state]}
          className="shrink-0 text-accent hover:text-accent-hover"
        >
          {LABEL_BY_STATE[state]}
        </button>
      </div>
    </div>
  );
}
