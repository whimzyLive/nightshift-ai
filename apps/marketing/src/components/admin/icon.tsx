const GLOW_ID = 'nightshift-admin-icon-glow';
const MASK_ID = 'nightshift-admin-icon-mask';

/**
 * Payload admin nav icon — the nightshift crescent-moon mark.
 * Geometry ported verbatim from `packages/ui/src/lib/nightshift/logomark.tsx`
 * (`variant="mark"`). Static ids instead of `useId` — Payload's graphics slot
 * renders this as a plain RSC, and a fixed id is safe since it mounts once.
 */
export function Icon() {
  return (
    <svg
      width={28}
      height={28}
      viewBox="0 0 120 120"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="nightshift"
    >
      <defs>
        <radialGradient id={GLOW_ID} cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#d97757" stopOpacity="0.45" />
          <stop offset="60%" stopColor="#d97757" stopOpacity="0.1" />
          <stop offset="100%" stopColor="#d97757" stopOpacity="0" />
        </radialGradient>
        <mask id={MASK_ID}>
          <rect width="120" height="120" fill="black" />
          <circle cx="58" cy="60" r="34" fill="white" />
          <circle cx="74" cy="50" r="30" fill="black" />
        </mask>
      </defs>
      <circle cx="60" cy="60" r="56" fill={`url(#${GLOW_ID})`} />
      <rect
        width="120"
        height="120"
        rx="34"
        fill="#d97757"
        mask={`url(#${MASK_ID})`}
      />
      <circle cx="86" cy="34" r="2.6" fill="#f5f3ef" />
      <circle cx="96" cy="52" r="1.8" fill="#f5f3ef" opacity="0.8" />
      <circle cx="82" cy="22" r="1.4" fill="#7c93f0" />
    </svg>
  );
}
