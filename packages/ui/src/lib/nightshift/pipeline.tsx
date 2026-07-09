import { Fragment } from 'react';

import styles from './pipeline.module.css';

type StageStatus = 'idle' | 'active' | 'done';

export interface PipelineStage {
  command: string;
  label?: string;
  agent?: string;
  /** @default 'idle' */
  status?: StageStatus;
}

export interface PipelineProps {
  stages: PipelineStage[];
  /** @default 'horizontal' */
  orientation?: 'horizontal' | 'vertical';
}

/**
 * nightshift Pipeline — the spec → plan → impl → review → PR flow as
 * connected blocks. Connectors turn green as stages complete.
 */
export function Pipeline({ stages, orientation = 'horizontal' }: PipelineProps) {
  const horizontal = orientation === 'horizontal';
  return (
    <div className={`${styles.pipeline} ${horizontal ? styles.horizontal : styles.vertical}`}>
      {stages.map((stage, i) => (
        <Fragment key={`${stage.command}-${i}`}>
          <Stage {...stage} />
          {i < stages.length - 1 && (
            <Connector horizontal={horizontal} done={stage.status === 'done'} />
          )}
        </Fragment>
      ))}
    </div>
  );
}

function Stage({ command, label, agent, status = 'idle' }: PipelineStage) {
  return (
    <div className={`${styles.stage} ${styles[`status-${status}`]}`}>
      <span className={styles.command}>
        {status === 'done' ? '✓ ' : ''}
        {command}
      </span>
      {label && <span className={styles.label}>{label}</span>}
      {agent && <span className={styles.agent}>{agent}</span>}
    </div>
  );
}

function Connector({ horizontal, done }: { horizontal: boolean; done: boolean }) {
  return (
    <div className={`${styles.connector} ${done ? styles.connectorDone : ''}`}>
      {horizontal ? '→' : '↓'}
    </div>
  );
}

export default Pipeline;
