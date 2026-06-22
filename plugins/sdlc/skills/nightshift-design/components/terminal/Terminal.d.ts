import * as React from 'react';

export interface TermLineSpec {
  text?: string;
  tone?: 'default' | 'success' | 'warning' | 'danger' | 'info' | 'muted' | 'accent';
  prompt?: string;
  agent?: string;
  indent?: number;
  dim?: boolean;
}

export interface TerminalProps {
  /** Title-bar text. @default "zsh — nightshift" */
  title?: string;
  /** Structured output lines; alternative to children. */
  lines?: (string | TermLineSpec)[];
  children?: React.ReactNode;
  showDot?: boolean;
  minHeight?: number | string;
  style?: React.CSSProperties;
}

/**
 * Terminal window frame — traffic lights, title bar, dark output body.
 * The signature surface of nightshift.
 * @startingPoint section="Terminal" subtitle="Terminal window with agent pipeline output" viewport="700x320"
 */
export function Terminal(props: TerminalProps): JSX.Element;
export function TermLine(props: TermLineSpec): JSX.Element;
