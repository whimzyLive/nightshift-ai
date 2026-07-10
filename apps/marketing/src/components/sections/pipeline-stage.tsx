import { Fragment } from 'react';

import type { PipelineStage } from '../../lib/sections-content';
import styles from './pipeline-stage.module.css';

export interface PipelineStageRowProps {
  stages: PipelineStage[];
}

// Connected stage blocks — spec → plan → impl → review → PR — connectors
// turn green as stages complete (nightshift-design references/components.md
// `Pipeline`).
export function PipelineStageRow({ stages }: PipelineStageRowProps) {
  return (
    <div className={styles.row} role="list" aria-label="/auto pipeline stages">
      {stages.map((stage, i) => (
        <Fragment key={stage.command}>
          {i > 0 && (
            <span
              aria-hidden="true"
              className={`${styles.connector} ${
                stages[i - 1].status === 'done' ? styles.done : ''
              }`}
            />
          )}
          <div
            role="listitem"
            className={`${styles.stage} ${
              stage.status === 'active' ? styles.active : ''
            }`}
          >
            <span className={styles.command}>{stage.command}</span>
            <span className={styles.label}>
              {stage.status === 'done' && (
                <span className={styles.check} aria-hidden="true">
                  ✓{' '}
                </span>
              )}
              {stage.label}
            </span>
          </div>
        </Fragment>
      ))}
    </div>
  );
}

export default PipelineStageRow;
