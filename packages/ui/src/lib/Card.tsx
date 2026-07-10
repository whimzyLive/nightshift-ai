export function Card({
  children,
  className = '',
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`rounded-lg border border-default bg-surface p-6 ${className}`}
    >
      {children}
    </div>
  );
}
