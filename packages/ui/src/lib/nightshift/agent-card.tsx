import styles from './agent-card.module.css';

type AgentTone = 'accent' | 'info' | 'cyan' | 'green';

export interface AgentCardProps {
  name: string;
  owns: string;
  /** Override the auto-generated monogram. */
  glyph?: string;
  /** @default 'accent' */
  tone?: AgentTone;
  status?: string;
  /** Dims conditional/standby roles. @default false */
  standby?: boolean;
}

function monogram(name: string): string {
  return name
    .split('-')
    .map((word) => word[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();
}

/**
 * nightshift AgentCard — a role in the AI software team. Mono name,
 * monogram avatar, what it owns. Builds the "meet your team" grid.
 */
export function AgentCard({ name, owns, glyph, tone = 'accent', status, standby = false }: AgentCardProps) {
  return (
    <div className={`${styles.card} ${standby ? styles.standby : ''}`}>
      <div className={styles.header}>
        <span className={`${styles.avatar} ${styles[`tone-${tone}`]}`}>{glyph ?? monogram(name)}</span>
        <span className={styles.nameCol}>
          <span className={styles.name}>{name}</span>
          {standby && <span className={styles.standbyTag}>standby</span>}
        </span>
      </div>
      <p className={styles.owns}>{owns}</p>
      {status && <span className={`${styles.status} ${styles[`tone-${tone}`]}`}>{status}</span>}
    </div>
  );
}

export default AgentCard;
