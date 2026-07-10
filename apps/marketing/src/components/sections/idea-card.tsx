import type { Ref } from 'react';

import type { PipelineIdea } from '../../lib/sections-content';
import styles from './idea-card.module.css';

export type IdeaCardProps = PipelineIdea & { ref?: Ref<HTMLDivElement> };

// React 19: ref is a plain prop, no forwardRef wrapper needed.
export function IdeaCard({ n, title, body, ref }: IdeaCardProps) {
  return (
    <div ref={ref} className={styles.card} data-testid="idea-card">
      <span className={styles.index}>{n}</span>
      <h3 className={styles.title}>{title}</h3>
      <p className={styles.body}>{body}</p>
    </div>
  );
}

export default IdeaCard;
