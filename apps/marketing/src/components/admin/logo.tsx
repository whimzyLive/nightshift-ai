const GLOW_ID = 'nightshift-admin-logo-glow';
const MASK_ID = 'nightshift-admin-logo-mask';

/**
 * Payload admin login-screen logo — the full nightshift lockup (moon mark +
 * "nightshift" wordmark) on a transparent background. Geometry ported
 * verbatim from `packages/ui/src/lib/nightshift/logomark.tsx`
 * (`variant="full"`). Static ids instead of `useId` — Payload's graphics slot
 * renders this as a plain RSC, and a fixed id is safe since it mounts once.
 */
export function Logo() {
  return (
    <svg
      width={150}
      height={40}
      viewBox="0 0 360 96"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="nightshift"
    >
      <defs>
        <radialGradient id={GLOW_ID} cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#d97757" stopOpacity="0.4" />
          <stop offset="60%" stopColor="#d97757" stopOpacity="0.08" />
          <stop offset="100%" stopColor="#d97757" stopOpacity="0" />
        </radialGradient>
        <mask id={MASK_ID}>
          <rect x="16" y="16" width="64" height="64" fill="black" />
          <circle cx="46" cy="48" r="25" fill="white" />
          <circle cx="58" cy="40" r="22" fill="black" />
        </mask>
      </defs>
      <circle cx="48" cy="48" r="44" fill={`url(#${GLOW_ID})`} />
      <rect
        x="16"
        y="16"
        width="64"
        height="64"
        rx="20"
        fill="#d97757"
        mask={`url(#${MASK_ID})`}
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
