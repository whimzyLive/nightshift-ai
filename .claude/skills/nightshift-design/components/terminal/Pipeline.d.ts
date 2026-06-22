import * as React from 'react';

export interface PipelineStage {
  /** Command or stage id, e.g. "/spec". */
  command: string;
  /** Human label, e.g. "Technical spec". */
  label?: string;
  /** Owning agent, e.g. "solutions-architect". */
  agent?: string;
  /** @default "idle" */
  status?: 'idle' | 'active' | 'done';
}

export interface PipelineProps {
  stages: PipelineStage[];
  /** @default "horizontal" */
  orientation?: 'horizontal' | 'vertical';
  style?: React.CSSProperties;
}

/**
 * The spec→plan→impl→review→PR flow as connected stage blocks.
 * @startingPoint section="Terminal" subtitle="Agent pipeline / flow diagram" viewport="700x140"
 */
export function Pipeline(props: PipelineProps): JSX.Element;
