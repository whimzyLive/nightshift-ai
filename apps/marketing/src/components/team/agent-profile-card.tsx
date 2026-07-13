import type { AgentProfile, ModelTier } from './roster-data';

const AGENT_URL =
  'https://github.com/whimzyLive/nightshift-ai/blob/main/plugins/sdlc/agents/';

// tier → color mirrors packages/ui's Badge tier tokens (opus=terra/accent,
// sonnet=indigo/info, human=green/success) — kept page-local per the spec's
// Open Question 1 (the design's 9.5px pill differs from Badge's 12px size).
const TIER_COLOR: Record<ModelTier, string> = {
  opus: 'var(--terra-400)',
  sonnet: 'var(--indigo-400)',
  human: 'var(--green-400)',
};

const TIER_BORDER: Record<ModelTier, string> = {
  opus: 'var(--border-accent)',
  sonnet: 'rgba(139,156,247,.4)',
  human: 'rgba(110,196,138,.45)',
};

const TIER_BADGE: Record<ModelTier, string> = {
  opus: 'OPUS',
  sonnet: 'SONNET',
  human: 'HUMAN',
};

/**
 * One profile card — matches `.team-card` in team.dc.html (L138-174).
 * Server component; the only interactivity is the CSS-only `:hover` lift
 * (`motion-safe:` gated), no client state.
 */
export function AgentProfileCard({ agent }: { agent: AgentProfile }) {
  const color = TIER_COLOR[agent.tier];
  const badge = agent.badgeOverride ?? TIER_BADGE[agent.tier];

  return (
    <div
      className="motion-safe:hover:-translate-y-[3px] motion-safe:transition-[border-color,transform,box-shadow] motion-safe:duration-300 motion-safe:ease-[var(--ease-out)] motion-safe:hover:shadow-[0_0_22px_rgba(217,119,87,.14),0_24px_50px_-28px_rgba(0,0,0,.8)] motion-safe:hover:border-[var(--border-accent)]"
      style={{
        // Glassmorphic surface — translucent over the starfield with a
        // backdrop blur + top highlight, matching the home workflow cards.
        background:
          'linear-gradient(180deg, rgba(255,255,255,0.05), rgba(13,13,24,0.45))',
        backdropFilter: 'var(--glass-blur)',
        WebkitBackdropFilter: 'var(--glass-blur)',
        border: '1px solid var(--glass-border)',
        boxShadow: 'var(--elev-2), inset 0 1px 0 rgba(255,255,255,0.06)',
        padding: '20px 22px',
        display: 'flex',
        flexDirection: 'column',
        gap: 12,
        // Uniform card height across every department — sized just above the
        // tallest card (~296px) so future copy has ~1 line of headroom without
        // desyncing the grid. `marginTop:auto` on the footer keeps the
        // flow/artifact row pinned to the bottom of the taller box.
        minHeight: 310,
      }}
    >
      <div className="flex items-center gap-3">
        <span className="font-mono font-bold" style={{ fontSize: 15, color }}>
          {agent.ini}
        </span>
        <div className="min-w-0 flex-1">
          <div
            className="font-mono"
            style={{ fontSize: 13.5, color: 'var(--moon-100)' }}
          >
            {agent.name}
          </div>
          <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
            {agent.title}
          </div>
        </div>
        <span
          className="font-mono"
          style={{
            fontSize: 9.5,
            letterSpacing: '.12em',
            padding: '3px 7px',
            border: `1px solid ${TIER_BORDER[agent.tier]}`,
            color,
          }}
        >
          {badge}
        </span>
      </div>
      <p
        style={{
          fontSize: 13,
          lineHeight: 1.55,
          color: 'var(--text-body)',
          margin: 0,
        }}
      >
        {agent.owns}
      </p>
      <div
        className="flex flex-col gap-[5px]"
        style={{
          borderTop: '1px solid var(--border-soft)',
          paddingTop: 9,
          marginTop: 'auto',
        }}
      >
        <span
          className="font-mono"
          style={{ fontSize: 10.5, color: 'var(--text-dim)' }}
        >
          {agent.flow}
        </span>
        <div className="flex justify-between gap-[10px]">
          <span
            className="font-mono"
            style={{ fontSize: 10.5, color: 'var(--cyan-400)' }}
          >
            → {agent.artifact}
          </span>
          {agent.file && (
            <a
              href={`${AGENT_URL}${agent.file}`}
              target="_blank"
              rel="noopener"
              className="font-mono whitespace-nowrap"
              style={{ fontSize: 10.5, color: 'var(--link)' }}
            >
              charter ↗
            </a>
          )}
        </div>
      </div>
      <p
        className="font-mono"
        style={{ fontSize: 11, color: 'var(--text-dim)', margin: 0 }}
      >
        {agent.fact}
      </p>
    </div>
  );
}
