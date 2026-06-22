import * as React from 'react';

export interface CodeBlockProps {
  /** The code/text to render. */
  code?: string;
  /** Language label shown in the header. @default "bash" */
  language?: string;
  /** Optional filename in the header. */
  filename?: string;
  showLineNumbers?: boolean;
  /** Show the copy button. @default true */
  copyable?: boolean;
  style?: React.CSSProperties;
}

/** Syntax-tinted code surface with copy button; tints shell prompts & conventional commits. */
export function CodeBlock(props: CodeBlockProps): JSX.Element;
