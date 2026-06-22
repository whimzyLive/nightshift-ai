import * as React from 'react';

export interface CommandCardProps {
  /** The slash command, e.g. "/auto". */
  command: string;
  /** Argument signature, e.g. "<TICKET>". */
  args?: string;
  description: string;
  /** Agents this command dispatches. */
  agents?: string[];
  /** Optional sample output line. */
  output?: string;
  style?: React.CSSProperties;
}

/**
 * Slash-command reference card for the docs command reference.
 * @startingPoint section="Data" subtitle="Command reference card" viewport="360x180"
 */
export function CommandCard(props: CommandCardProps): JSX.Element;
