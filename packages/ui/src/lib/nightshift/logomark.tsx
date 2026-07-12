import { useId } from 'react';

export interface LogomarkProps {
  /** `mark` = crescent-moon icon only. `full` = icon + "nightshift" wordmark lockup. */
  variant?: 'mark' | 'full';
  size?: number;
  className?: string;
}

/**
 * Inline SVG brand mark, ported verbatim from
 * docs/design/marketing-site-handoff/assets/{logomark,logo}.svg — never
 * retypeset the wordmark; the `full` variant reuses the design file's own
 * <text> glyphs rather than recreating them in HTML. IDs are namespaced
 * per-instance (useId) so multiple placements (nav + footer) don't collide.
 */
export function Logomark({
  variant = 'mark',
  size = 28,
  className = '',
}: LogomarkProps) {
  const uid = useId();

  if (variant === 'full') {
    const glowId = `${uid}-lgGlow`;
    const maskId = `${uid}-lgCrescent`;
    const width = size * (360 / 96);
    return (
      <svg
        width={width}
        height={size}
        viewBox="0 0 360 96"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        role="img"
        aria-label="nightshift"
        className={className}
      >
        <defs>
          <radialGradient id={glowId} cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#d97757" stopOpacity="0.4" />
            <stop offset="60%" stopColor="#d97757" stopOpacity="0.08" />
            <stop offset="100%" stopColor="#d97757" stopOpacity="0" />
          </radialGradient>
          <mask id={maskId}>
            <rect x="16" y="16" width="64" height="64" fill="black" />
            <circle cx="46" cy="48" r="25" fill="white" />
            <circle cx="58" cy="40" r="22" fill="black" />
          </mask>
        </defs>
        <circle cx="48" cy="48" r="44" fill={`url(#${glowId})`} />
        <rect
          x="16"
          y="16"
          width="64"
          height="64"
          rx="20"
          fill="#d97757"
          mask={`url(#${maskId})`}
        />
        <circle cx="68" cy="26" r="2" fill="#f5f3ef" />
        <circle cx="76" cy="40" r="1.4" fill="#f5f3ef" opacity="0.8" />
        <text
          x="100"
          y="59"
          fontFamily="'JetBrains Mono','SFMono-Regular',monospace"
          fontSize="32"
          fontWeight="700"
          letterSpacing="-0.5"
          fill="#f5f3ef"
        >
          night
          <tspan fill="#d97757">shift</tspan>
        </text>
      </svg>
    );
  }

  const glowId = `${uid}-nsGlow`;
  const maskId = `${uid}-nsCrescent`;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 120 120"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="nightshift moon mark"
      className={className}
    >
      <defs>
        <radialGradient id={glowId} cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#d97757" stopOpacity="0.45" />
          <stop offset="60%" stopColor="#d97757" stopOpacity="0.1" />
          <stop offset="100%" stopColor="#d97757" stopOpacity="0" />
        </radialGradient>
        <mask id={maskId}>
          <rect width="120" height="120" fill="black" />
          <circle cx="58" cy="60" r="34" fill="white" />
          <circle cx="74" cy="50" r="30" fill="black" />
        </mask>
      </defs>
      <circle cx="60" cy="60" r="56" fill={`url(#${glowId})`} />
      <rect
        width="120"
        height="120"
        rx="34"
        fill="#d97757"
        mask={`url(#${maskId})`}
      />
      <circle cx="86" cy="34" r="2.6" fill="#f5f3ef" />
      <circle cx="96" cy="52" r="1.8" fill="#f5f3ef" opacity="0.8" />
      <circle cx="82" cy="22" r="1.4" fill="#7c93f0" />
    </svg>
  );
}
