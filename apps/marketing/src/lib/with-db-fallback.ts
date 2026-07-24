import { isConnectionOrInitError } from './is-connection-error';

/**
 * Runs a Payload query, rethrowing a connection/init-class failure (so a
 * build against an unavailable DB fails fast) and swallowing anything else
 * to `fallback` after logging it — the shared policy behind every
 * `lib/faq.ts`/`lib/why-sdlc.ts` reader.
 */
export async function withDbFallback<T>(
  logTag: string,
  fallback: T,
  operation: () => Promise<T>,
): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    if (isConnectionOrInitError(error)) throw error;
    console.error(logTag, error);
    return fallback;
  }
}
