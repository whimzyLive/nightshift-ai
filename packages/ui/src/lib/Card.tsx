export function Card({
  children,
  className = '',
}: {
  children: React.ReactNode;
  className?: string;
}) {
  // ns-card recipe (.claude/skills/nightshift-design/references/patterns.md):
  // hairline + deep soft shadow at rest, lift + warm border + deeper shadow
  // on hover — the hairline is required on dark, shadow alone won't read.
  return (
    <div
      className={`rounded-lg border border-default bg-surface p-6 shadow-elev-2 transition duration-200 ease-out hover:-translate-y-0.5 hover:border-line-strong hover:shadow-elev-3 ${className}`}
    >
      {children}
    </div>
  );
}
