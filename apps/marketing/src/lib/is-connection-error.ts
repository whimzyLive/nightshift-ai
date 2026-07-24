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

const SQLSTATE_EXACT_CODES = [
  '42P01', // undefined_table (unmigrated schema)
  '3F000', // invalid_schema_name (unmigrated schema)
  '3D000', // invalid_catalog_name (database does not exist)
  '57P01', // admin_shutdown
  '57P02', // crash_shutdown
  '57P03', // cannot_connect_now (server starting/recovering)
  '53300', // too_many_connections
];

// Connection (08*) / auth (28*) classes only — 57/53 are NOT matched
// class-wide because they also cover query-scoped conditions (57014
// query_canceled/statement_timeout) and other resource states (53100/
// 53200/53400) that don't indicate the DB itself is unavailable.
const SQLSTATE_CLASS_PATTERN = /^(08|28)/;

// node-postgres throws several genuine connection failures with no `code`
// property at all, only a message — a small, explicit allowlist (not
// general message matching, which would over-fail on unrelated errors).
const CONNECTION_MESSAGE_SUBSTRINGS = [
  'timeout exceeded when trying to connect',
  'connection terminated unexpectedly',
  'connection terminated due to connection timeout',
];

// Real outages can wrap several layers deep (Payload -> Drizzle -> pg-pool
// -> pg-client -> socket, plus an AggregateError layer) — 10 is ample
// headroom while staying bounded against cyclic/pathological chains.
const MAX_CAUSE_DEPTH = 10;

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

function readSubErrors(value: unknown): unknown[] | undefined {
  if (value && typeof value === 'object' && 'errors' in value) {
    const errors = (value as { errors?: unknown }).errors;
    if (Array.isArray(errors)) return errors;
  }
  return undefined;
}

function readMessage(value: unknown): string | undefined {
  if (value && typeof value === 'object' && 'message' in value) {
    const message = (value as { message?: unknown }).message;
    if (typeof message === 'string') return message;
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

function isUnavailableMessage(message: string): boolean {
  const lower = message.toLowerCase();
  return CONNECTION_MESSAGE_SUBSTRINGS.some((substring) =>
    lower.includes(substring),
  );
}

/**
 * True when an error indicates the database is unavailable — unreachable,
 * unauthenticated, on an unmigrated/missing schema or catalog, restarting,
 * or overloaded — i.e. a build-breaking outage, not an isolated
 * row/data-shape defect. Inspects a Node/pg network `code`, a Postgres
 * SQLSTATE, or (for the several genuine pg driver connection failures that
 * carry no `code` at all) a narrow message allowlist — on the error itself,
 * recursing through `error.cause` (Payload/Drizzle commonly wrap the driver
 * error) and through `error.errors[]` (Node's `AggregateError` from
 * happy-eyeballs multi-address connect attempts), depth-guarded against
 * pathological/cyclic chains. Accepts any thrown value, not just `Error`
 * instances, since a serialized or aggregate error may carry a `code`
 * without being an `Error`.
 */
export function isConnectionOrInitError(error: unknown, depth = 0): boolean {
  if (depth > MAX_CAUSE_DEPTH || error == null) return false;

  const code = readCode(error);
  if (code && isUnavailableCode(code)) return true;

  const message = readMessage(error);
  if (message && isUnavailableMessage(message)) return true;

  const subErrors = readSubErrors(error);
  if (
    subErrors?.some((subError) => isConnectionOrInitError(subError, depth + 1))
  ) {
    return true;
  }

  const cause = readCause(error);
  if (cause === undefined) return false;
  return isConnectionOrInitError(cause, depth + 1);
}
