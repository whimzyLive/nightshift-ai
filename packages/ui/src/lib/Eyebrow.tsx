export function Eyebrow({ children }: { children: React.ReactNode }) {
  return (
    <span className="font-mono text-xs uppercase tracking-eyebrow text-accent">
      {'// '}
      {children}
    </span>
  );
}
