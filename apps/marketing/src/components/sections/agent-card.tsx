import type { CSSProperties, Ref } from 'react';

import type { Agent } from '../../lib/sections-content';
import styles from './agent-card.module.css';

export type AgentCardProps = Agent & { ref?: Ref<HTMLDivElement> };

const TONE_COLORS: Record<Agent['tone'], string> = {
  accent: 'var(--ns-accent)',
  info: 'var(--ns-indigo-400)',
  cyan: 'var(--ns-cyan-400)',
  green: 'var(--ns-green-400)',
};

function monogram(name: string): string {
  const parts = name.split('-');
  return parts.length > 1 ? `${parts[0][0]}${parts[1][0]}` : name.slice(0, 2);
}

export function AgentCard({ name, owns, tone, standby, ref }: AgentCardProps) {
  const toneColor = TONE_COLORS[tone];
  const toneStyle = {
    '--ns-tone': toneColor,
    '--ns-tone-tint': `color-mix(in srgb, ${toneColor} 14%, transparent)`,
  } as CSSProperties;

  return (
    <div
      ref={ref}
      className={`${styles.card} ${standby ? styles.standby : ''}`}
      style={toneStyle}
      data-testid={`agent-card-${name}`}
    >
      <span className={styles.monogram} aria-hidden="true">
        {monogram(name)}
      </span>
      <div>
        <p className={styles.name}>{name}</p>
        <p className={styles.owns}>{owns}</p>
        {standby && <span className={styles.standbyLabel}>standby</span>}
      </div>
    </div>
  );
}

export default AgentCard;
