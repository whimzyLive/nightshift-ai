import { getPayload, type Payload } from 'payload';

import config from '../payload.config';

let cached: Promise<Payload> | null = null;
export function getPayloadClient(): Promise<Payload> {
  if (!cached) {
    // Clear the poisoned promise on rejection so a transient failure (e.g. a
    // Neon blip) doesn't permanently 500 every request until process
    // restart — a plain `cached ??= getPayload(...)` never clears a
    // rejected promise the way Payload's own getPayload resets on init
    // failure. Memoization on success is preserved: `cached` stays set to
    // the resolved promise.
    cached = getPayload({ config }).catch((error: unknown) => {
      cached = null;
      throw error;
    });
  }
  return cached;
}
