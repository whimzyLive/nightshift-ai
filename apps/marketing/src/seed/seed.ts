import config from '@payload-config';
import { getPayload } from 'payload';

import { faqSeedData, whySdlcSeedData } from './data';

/**
 * Idempotent Local-API seed. Upserts each `faq` doc by its stable `seedKey`
 * (never duplicates on re-run) and overwrites the singleton `whySdlc` global.
 *
 * The body runs as a top-level await, not a fire-and-forget async IIFE:
 * `payload run <script>` calls `process.exit(0)` as soon as the dynamic
 * `import()` of this module settles, and dynamic import only waits on a
 * module's *top-level* await — an unawaited inner async function starts
 * the DB work but the CLI exits before any of it (including the first
 * `getPayload` call) completes.
 */
const payload = await getPayload({ config });

for (const record of faqSeedData) {
  const existing = await payload.find({
    collection: 'faq',
    where: { seedKey: { equals: record.seedKey } },
    limit: 1,
  });

  const existingDoc = existing.docs[0];
  if (existingDoc) {
    await payload.update({
      collection: 'faq',
      id: existingDoc.id,
      data: record,
    });
    payload.logger.info(`[seed] updated faq: ${record.seedKey}`);
  } else {
    await payload.create({ collection: 'faq', data: record });
    payload.logger.info(`[seed] created faq: ${record.seedKey}`);
  }
}

await payload.updateGlobal({ slug: 'whySdlc', data: whySdlcSeedData });
payload.logger.info('[seed] updated global: whySdlc');
