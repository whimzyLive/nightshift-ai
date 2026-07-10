/**
 * The brand glyph — a terracotta crescent with two faint stars, per
 * .claude/skills/nightshift-design/references/patterns.md "Icons" (brand
 * mark: crescent-moon, terracotta + glow + 2 stars). Hand-drawn inline SVG
 * rather than the skill's `assets/logomark.svg` file so it ships with no
 * extra asset/copy step and always tracks the `--color-accent` token.
 */
export function MoonMark({ className = '' }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 28 28"
      aria-hidden="true"
      className={`h-7 w-7 shrink-0 ${className}`}
    >
      <path
        d="M18.5 4a10 10 0 1 0 0 20 8 8 0 0 1 0-20Z"
        className="fill-accent"
      />
      <circle cx="22" cy="6.5" r="1" className="fill-accent" opacity="0.8" />
      <circle cx="24.5" cy="11" r="0.6" className="fill-accent" opacity="0.6" />
    </svg>
  );
}
