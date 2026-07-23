import * as migration_20260712_054942_na31_faq_and_why_sdlc from './20260712_054942_na31_faq_and_why_sdlc';
import * as migration_20260723_152746_na70_pages from './20260723_152746_na70_pages';

export const migrations = [
  {
    up: migration_20260712_054942_na31_faq_and_why_sdlc.up,
    down: migration_20260712_054942_na31_faq_and_why_sdlc.down,
    name: '20260712_054942_na31_faq_and_why_sdlc',
  },
  {
    up: migration_20260723_152746_na70_pages.up,
    down: migration_20260723_152746_na70_pages.down,
    name: '20260723_152746_na70_pages',
  },
];
