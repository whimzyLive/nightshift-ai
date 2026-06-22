import * as React from 'react';

export interface TableColumn {
  key: string;
  header: string;
  align?: 'left' | 'center' | 'right';
  /** Render this column's cells in monospace. */
  mono?: boolean;
  /** Muted cell text. */
  muted?: boolean;
}

export interface TableProps {
  columns: TableColumn[];
  /** Row objects keyed by column.key; values may be strings or React nodes. */
  rows: Record<string, React.ReactNode>[];
  /** Tighter row padding. @default false */
  dense?: boolean;
  style?: React.CSSProperties;
}

/** Quiet data table on the night palette — mono headers, hairline rows, hover highlight. */
export function Table(props: TableProps): JSX.Element;
