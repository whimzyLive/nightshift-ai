let hasWarnedDbNotConfigured = false;

/**
 * True when `DATABASE_URL` is present and non-blank. CI environments that
 * build without secrets leave it unset/empty — that's a deliberate,
 * expected "no DB available" state, distinct from a configured DB that's
 * unreachable (which still fails the build via `isConnectionOrInitError`).
 */
export function isDbConfigured(): boolean {
  return !!process.env.DATABASE_URL?.trim();
}

/**
 * Logs the "building without a DB" warning at most once per process, even
 * when several readers short-circuit in the same build (parallel static
 * generation workers each import a fresh module instance, but within one
 * worker this dedupes to a single line).
 */
export function warnDbNotConfiguredOnce(): void {
  if (hasWarnedDbNotConfigured) return;
  hasWarnedDbNotConfigured = true;
  console.warn(
    'DATABASE_URL not set — building marketing with empty CMS content (not a deployable artifact)',
  );
}

/** Test-only: resets the warn-once latch between test cases. */
export function __resetDbConfigWarningForTests(): void {
  hasWarnedDbNotConfigured = false;
}
