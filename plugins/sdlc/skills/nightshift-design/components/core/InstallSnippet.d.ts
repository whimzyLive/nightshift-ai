import * as React from 'react';

export interface InstallSnippetProps {
  /** The command to display & copy. @default "/plugin install sdlc@nightshift" */
  command?: string;
  /** Leading prompt glyph. @default "$" */
  prompt?: string;
  /** Optional uppercase mono label above the line. */
  label?: string;
}

/**
 * Copy-to-clipboard command line — the "install in 60 seconds" affordance.
 * @startingPoint section="Core" subtitle="Copy-to-clipboard install command" viewport="700x120"
 */
export function InstallSnippet(props: InstallSnippetProps): JSX.Element;
