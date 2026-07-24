/**
 * True when an error indicates the database was unreachable or unauthenticated
 * — i.e. a build-breaking outage, not an isolated row defect. Connection-class
 * errors carry a Node/pg network `code` or a Postgres SQLSTATE in the
 * connection (08*) / auth (28*) classes.
 */
export function isConnectionOrInitError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  const code = (error as { code?: unknown }).code;
  if (typeof code === 'string') {
    if (
      ['ECONNREFUSED', 'ENOTFOUND', 'ETIMEDOUT', 'ECONNRESET'].includes(code)
    ) {
      return true;
    }
    if (/^(08|28)/.test(code)) return true;
  }
  return false;
}
