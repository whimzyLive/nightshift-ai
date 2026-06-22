import * as React from 'react';

export interface AgentCardProps {
  /** Agent id, e.g. "product-manager". */
  name: string;
  /** One line on what the agent owns. */
  owns: string;
  /** Override the auto monogram glyph. */
  glyph?: string;
  /** Avatar accent tone. @default "accent" */
  tone?: 'accent' | 'info' | 'cyan' | 'green';
  /** Optional status line, e.g. "active". */
  status?: string;
  /** Dim + "standby" label for conditional roles. @default false */
  standby?: boolean;
  style?: React.CSSProperties;
}

/**
 * A role in the AI software team — for the "meet your team" grid.
 * @startingPoint section="Data" subtitle="Agent / role card" viewport="320x160"
 */
export function AgentCard(props: AgentCardProps): JSX.Element;
