export function Badge({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-flex items-center rounded-full border border-default bg-surface px-2.5 py-0.5 font-mono text-xs text-muted">
      {children}
    </span>
  );
}
