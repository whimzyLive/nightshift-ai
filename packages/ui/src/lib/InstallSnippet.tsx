'use client';
import { useState } from 'react';

export function InstallSnippet({ command }: { command: string }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    await navigator.clipboard.writeText(command);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };
  return (
    <div className="flex items-center justify-between gap-4 rounded-md bg-surface-terminal px-4 py-3 font-mono text-sm text-body">
      <code>{command}</code>
      <button
        type="button"
        onClick={copy}
        aria-label="Copy install command"
        className="text-accent hover:text-accent-hover"
      >
        {copied ? 'Copied' : 'Copy'}
      </button>
    </div>
  );
}
