import { getPayload, type Payload } from 'payload';

import config from '../payload.config';

let cached: Promise<Payload> | null = null;
export function getPayloadClient(): Promise<Payload> {
  cached ??= getPayload({ config });
  return cached;
}
