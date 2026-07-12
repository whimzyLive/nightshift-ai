// Verbatim from the design handoff (nightshift Landing.dc.html L190-195) —
// the duplicated-track phrase set. Two copies of the same line let the
// `ns-marquee` -50% translate loop seamlessly.
const PHRASE_LINE =
  'you sleep, it ships ✦ spec before plan ✦ plan before code ✦ review before merge ✦ tests as the gate ✦ a team, not a megaprompt ✦ generic agents, per-repo config ✦ ';

/**
 * Decorative looping mono ticker dividing Hero from the Proof bar. Purely
 * illustrative — hidden from assistive tech. Frozen under reduced motion by
 * the global `ns-marquee` reduced-motion guard in global.css.
 */
export function PhraseMarquee() {
  return (
    <div
      aria-hidden="true"
      className="relative left-1/2 right-1/2 z-[1] -mx-[50vw] w-screen overflow-hidden border-t"
      style={{
        background: 'var(--surface-terminal)',
        borderColor: 'var(--border-default)',
      }}
    >
      <div className="flex w-max animate-[ns-marquee_var(--dur-marquee)_linear_infinite]">
        {[0, 1].map((copy) => (
          <span
            key={copy}
            className="font-mono whitespace-pre uppercase"
            style={{
              fontSize: 13,
              letterSpacing: '0.16em',
              color: 'var(--text-dim)',
              padding: '12px 0',
            }}
          >
            {PHRASE_LINE}
          </span>
        ))}
      </div>
    </div>
  );
}
