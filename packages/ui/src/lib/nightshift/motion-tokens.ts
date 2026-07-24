// Matches the site-wide `--ease-out` token (cubic-bezier(.22,1,.36,1)) used
// across every tweened animation in the animated home/why-sdlc sections.
// Single canonical export — every consumer imports this instead of
// re-declaring the tuple locally.
export const EASE_OUT: [number, number, number, number] = [0.22, 1, 0.36, 1];

// B2 settle-spring config for `Reveal`'s opt-in `spring` prop. Single
// canonical export — every consumer imports this instead of re-declaring it.
export const SETTLE_SPRING = { stiffness: 120, damping: 18 } as const;
