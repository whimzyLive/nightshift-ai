import type { CSSProperties, ReactNode } from 'react';

import styles from './terminal.module.css';

export type TermLineTone =
  | 'default'
  | 'success'
  | 'warning'
  | 'danger'
  | 'info'
  | 'muted'
  | 'accent';

export interface TermLineSpec {
  text?: string;
  tone?: TermLineTone;
  prompt?: string;
  agent?: string;
  indent?: number;
  dim?: boolean;
}

export interface TerminalProps {
  /** @default 'zsh — nightshift' */
  title?: string;
  /** Structured output lines; alternative to children. */
  lines?: (string | TermLineSpec)[];
  children?: ReactNode;
  showDot?: boolean;
  minHeight?: number | string;
  style?: CSSProperties;
}

function normalize(line: string | TermLineSpec): TermLineSpec {
  return typeof line === 'string' ? { text: line } : line;
}

/**
 * nightshift Terminal — window frame with traffic lights + title bar and a
 * dark output body. The signature surface of the brand.
 */
export function Terminal({
  title = 'zsh — nightshift',
  lines,
  children,
  showDot = true,
  minHeight,
  style,
}: TerminalProps) {
  return (
    <div className={styles.terminal} style={style}>
      <div className={styles.titlebar}>
        {showDot && (
          <span className={styles.dots} aria-hidden="true">
            <span className={`${styles.dot} ${styles.dotRed}`} />
            <span className={`${styles.dot} ${styles.dotAmber}`} />
            <span className={`${styles.dot} ${styles.dotGreen}`} />
          </span>
        )}
        <span className={styles.title}>{title}</span>
      </div>
      <div className={styles.body} style={{ minHeight }}>
        {lines ? lines.map((line, i) => <TermLine key={i} {...normalize(line)} />) : children}
      </div>
    </div>
  );
}

/**
 * A single terminal line. `tone` colors the glyph + text; `prompt` renders a
 * leading prompt; `agent` renders an agent name in accent.
 */
export function TermLine({ text, tone = 'default', prompt, agent, indent = 0, dim = false }: TermLineSpec) {
  const classes = [styles.line, dim ? styles.dim : styles[`tone-${tone}`]].join(' ');
  return (
    <div className={classes} style={{ paddingLeft: indent * 18 }}>
      {prompt && <span className={styles.prompt}>{prompt}</span>}
      {agent && <span className={styles.agent}>{agent}</span>}
      {agent && text ? ' ' : ''}
      {text}
    </div>
  );
}

export default Terminal;
