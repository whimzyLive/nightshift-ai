const NETWORK_CODES = [
  'ECONNREFUSED',
  'ENOTFOUND',
  'ETIMEDOUT',
  'ECONNRESET',
  'EPIPE',
  'EHOSTUNREACH',
  'ENETUNREACH',
  'EAI_AGAIN',
];

const SQLSTATE_EXACT_CODES = ['42P01', '3F000'];

const SQLSTATE_CLASS_PATTERN = /^(08|28|57|53)/;

const MAX_CAUSE_DEPTH = 5;

function readCode(value: unknown): string | undefined {
  if (value && typeof value === 'object' && 'code' in value) {
    const code = (value as { code?: unknown }).code;
    if (typeof code === 'string') return code;
  }
  return undefined;
}

function readCause(value: unknown): unknown {
  if (value && typeof value === 'object' && 'cause' in value) {
    return (value as { cause?: unknown }).cause;
  }
  return undefined;
}

function isUnavailableCode(code: string): boolean {
  return (
    NETWORK_CODES.includes(code) ||
    SQLSTATE_EXACT_CODES.includes(code) ||
    SQLSTATE_CLASS_PATTERN.test(code)
  );
}

/**
 * True when an error indicates the database is unavailable — unreachable,
 * unauthenticated, on an unmigrated schema, restarting, or overloaded — i.e.
 * a build-breaking outage, not an isolated row/data-shape defect. Inspects
 * a Node/pg network `code` or Postgres SQLSTATE on the error itself and
 * recurses through `error.cause` (Payload/Drizzle commonly wrap the driver
 * error), depth-guarded against pathological/cyclic cause chains. Accepts
 * any thrown value, not just `Error` instances, since a serialized or
 * aggregate error may carry a `code` without being an `Error`.
 */
export function isConnectionOrInitError(error: unknown, depth = 0): boolean {
  if (depth > MAX_CAUSE_DEPTH || error == null) return false;

  const code = readCode(error);
  if (code && isUnavailableCode(code)) return true;

  const cause = readCause(error);
  if (cause === undefined) return false;
  return isConnectionOrInitError(cause, depth + 1);
}
